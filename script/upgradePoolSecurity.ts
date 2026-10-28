/**
 * Pool security upgrade (2026-09 audit fixes) — see docs/pool-security-upgrade-2026-09.md.
 *
 * Steps (UPGRADE_STEP):
 *   plan      read-only: current implementation, linked libraries, owner/pauser, stuck paymaster fees
 *   deploy    any funded EOA: deploys QueuedMerkleTreeLogic, ShieldedTransactionLogic, the Pool
 *             implementation and (if OLD_PAYMASTERS is set) a replacement Paymaster, then writes
 *             deployments/pool-security-upgrade-<chainId>.json with the owner transactions
 *   verify    read-only: checks deployed bytecode against this build, the proxy's implementation
 *             and version, preserved state, and probes the new checks with eth_call
 *   rehearse  local fork only: deploy + execute the owner transactions by impersonation + verify
 *
 * Env:
 *   POOL_PROXY      pool proxy address (required)
 *   OLD_PAYMASTERS  comma-separated Paymasters the pool has credited fees to, CURRENT ONE FIRST
 *                   (it is the configuration template for the replacement). Enables fee recovery
 *                   and Paymaster replacement (optional)
 *   FEE_RECIPIENT   receives the recovered paymaster fees (default: pool owner)
 *   NEW_PAYMASTER_OWNER  owner of the replacement Paymaster (default: pool owner)
 *   PROBE_DEPOSIT_ASSET_ID / PROBE_DEPOSIT_AMOUNT
 *                   deposit used by the fee probe; must be within the pool's deposit USD bounds
 *                   (default 65538 / 20000000 = 20 USDC on Ethereum)
 *
 * Usage:
 *   UPGRADE_STEP=plan     POOL_PROXY=0x.. npx hardhat run script/upgradePoolSecurity.ts --network mainnet
 *   UPGRADE_STEP=rehearse POOL_PROXY=0x.. OLD_PAYMASTERS=0x..,0x.. npx hardhat run script/upgradePoolSecurity.ts --network mainnetFork
 */
import hre from "hardhat";
import fs from "fs";
import path from "path";
import {
    Abi, Hex, encodeFunctionData, getAddress, isAddressEqual, keccak256, toHex,
    BaseError, ContractFunctionRevertedError, decodeErrorResult, pad,
} from "viem";

type Addr = `0x${string}`;

const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
// OZ PausableUpgradeable ERC-7201 namespace ("openzeppelin.storage.Pausable")
const PAUSABLE_SLOT = "0xcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300";
const LIB_NAMES = ["AssetLogic", "MerkleTreeLogic", "QueuedMerkleTreeLogic", "ShieldedAddressLogic", "ShieldedTransactionLogic"] as const;
type LibName = typeof LIB_NAMES[number];
type Libs = Record<LibName, Addr>;

const step = (process.env.UPGRADE_STEP ?? "plan").toLowerCase();
const POOL_PROXY = process.env.POOL_PROXY as Addr;
const OLD_PAYMASTERS = (process.env.OLD_PAYMASTERS ?? "").split(",").map(x => x.trim()).filter(Boolean)
    .map(x => getAddress(x) as Addr);

const art = (name: string) => hre.artifacts.readArtifactSync(name);
const poolAbi = art("Pool").abi as Abi;
const paymasterAbi = art("Paymaster").abi as Abi;
// Library errors are not all in the Pool ABI; merge them so reverts decode.
const errorAbi = [
    ...poolAbi,
    ...(art("QueuedMerkleTreeLogic").abi as Abi),
    ...(art("ShieldedTransactionLogic").abi as Abi),
    ...(art("IScreener").abi as Abi),
].filter((x: any) => x.type === "error") as Abi;

let client: any;
let chainId: number;

const isLocal = () => hre.network.name === "hardhat" || /127\.0\.0\.1|localhost/.test((hre.network.config as any).url ?? "");
// Fork runs get their own file so a rehearsal can never be mistaken for the real deployment record.
const outFile = () => path.join(__dirname, "..", "deployments",
    `pool-security-upgrade-${chainId}${isLocal() ? "-fork-rehearsal" : ""}.json`);
const read = (address: Addr, functionName: string, args: any[] = [], abi: Abi = poolAbi) =>
    client.readContract({ address, abi, functionName, args });

// ---------------------------------------------------------------------------
// Bytecode helpers
// ---------------------------------------------------------------------------

/** Operands of every PUSH20 in `code` (opcode-aware, so push data is never misread as an opcode). */
const push20Operands = (code: string): Addr[] => {
    const hex = code.startsWith("0x") ? code.slice(2) : code;
    const out = new Set<string>();
    for (let i = 0; i < hex.length / 2; ) {
        const op = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
        if (op === 0x73) out.add("0x" + hex.slice((i + 1) * 2, (i + 21) * 2));
        i += op >= 0x60 && op <= 0x7f ? op - 0x5f + 1 : 1;
    }
    return Array.from(out).map(a => getAddress(a) as Addr);
};

/**
 * Libraries linked into a deployed contract that was built from different source (so this
 * build's link offsets do not apply): every PUSH20 target that has code is matched against
 * this build's library artifacts. A match proves the library's source is unchanged.
 */
const identifyLinkedLibs = async (address: Addr) => {
    const code: string = (await client.getCode({ address })) ?? "0x";
    const found: Partial<Libs> = {};
    const unmatched: Addr[] = [];
    const candidates = push20Operands(code);
    // Pass 1: libraries with no links of their own; pass 2: those linking pass-1 libraries.
    for (const pass of [1, 2]) {
        for (const a of candidates) {
            if (Object.values(found).some(x => isAddressEqual(x!, a))) continue;
            if (((await client.getCode({ address: a })) ?? "0x").length <= 2) continue;
            let hit = false;
            for (const lib of LIB_NAMES) {
                if (found[lib]) continue;
                try {
                    // Metadata is ignored: it hashes every imported source, and IPool.sol (imported by
                    // AssetLogic and ShieldedAddressLogic) gained two error declarations.
                    if (await matchesBuild(a, lib, found, "library", true)) { found[lib] = a; hit = true; break; }
                } catch { /* needs a library not identified yet */ }
            }
            if (!hit && pass === 2) unmatched.push(a);
        }
    }
    return { found, unmatched };
};

/** Artifact runtime bytecode with library placeholders replaced by `libs`. */
const linkedRuntime = (artifactName: string, libs: Partial<Libs>): string => {
    const a = art(artifactName);
    let code = a.deployedBytecode.slice(2).toLowerCase();
    for (const file of Object.values(a.deployedLinkReferences as Record<string, Record<string, { start: number }[]>>)) {
        for (const [lib, offsets] of Object.entries(file)) {
            const addr = libs[lib as LibName];
            if (!addr) throw new Error(`${artifactName}: no address for linked library ${lib}`);
            for (const o of offsets) {
                code = code.slice(0, o.start * 2) + addr.slice(2).toLowerCase() + code.slice((o.start + 20) * 2);
            }
        }
    }
    return code;
};

/**
 * Compares on-chain runtime code with this build. Masks what legitimately differs:
 * a library's call-protection address (PUSH20 at byte 1) and a contract's address
 * immutables (the UUPS `__self` for the Pool; entryPoint/sender/pool for the Paymaster).
 */
const matchesBuild = async (
    address: Addr, artifactName: string, libs: Partial<Libs>, kind: "library" | "contract", ignoreMetadata = false,
    immutables: Addr[] = [address],
) => {
    let onchain: string = ((await client.getCode({ address })) ?? "0x").slice(2).toLowerCase();
    let expected = linkedRuntime(artifactName, libs);
    if (kind === "library") {
        onchain = onchain.slice(0, 2) + "00".repeat(20) + onchain.slice(42);
    } else {
        // Address immutables are stored as 32-byte words that are zero in the artifact.
        for (const imm of immutables) onchain = onchain.split(pad(imm).slice(2).toLowerCase()).join("00".repeat(32));
    }
    if (ignoreMetadata) {
        onchain = stripMetadata(onchain);
        expected = stripMetadata(expected);
    }
    return onchain.length > 0 && onchain === expected;
};

/** Drops the trailing CBOR metadata (its length is the last two bytes). */
const stripMetadata = (hex: string) => hex.slice(0, hex.length - (parseInt(hex.slice(-4), 16) + 2) * 2);

// ---------------------------------------------------------------------------
// State snapshot
// ---------------------------------------------------------------------------

const snapshot = async (oldPaymasters: Addr[]) => {
    const [, cmSubtrees, cmRoot, cmRootIdx, cmNext] = await read(POOL_PROXY, "getCommitmentTreeState");
    const [, addrRoot, addrRootIdx, addrNext] = await read(POOL_PROXY, "getAddressTreeState");
    const assets: Record<string, any> = {};
    // Asset ids are assigned sequentially from 65537; stop after a run of empty ids.
    for (let id = 65537, misses = 0; misses < 3; id++) {
        try {
            const a: any = await read(POOL_PROXY, "getAsset", [id]);
            if (a.assetAddress === "0x0000000000000000000000000000000000000000") { misses++; continue; }
            misses = 0;
            const bal = await client.readContract({
                address: a.assetAddress, functionName: "balanceOf", args: [POOL_PROXY],
                abi: [{ type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ type: "address" }], outputs: [{ type: "uint256" }] }],
            });
            assets[id] = {
                address: a.assetAddress, active: a.isActive, balance: bal.toString(),
                withdrawFees: (await read(POOL_PROXY, "getCollectedWithdrawFee", [id])).toString(),
                // Keyed by paymaster: fees credited to each old Paymaster for this asset.
                paymasterFees: Object.fromEntries(await Promise.all(oldPaymasters.map(async pm =>
                    [pm, (await read(POOL_PROXY, "getCollectedPaymasterFee", [id, pm])).toString()]))),
            };
        } catch { misses++; }
    }
    return {
        owner: await read(POOL_PROXY, "owner"),
        pauser: await read(POOL_PROXY, "pauser"),
        paused: await read(POOL_PROXY, "paused"),
        version: (await read(POOL_PROXY, "version")).toString(),
        verifier: await read(POOL_PROXY, "verifier"),
        commitmentTree: {
            root: cmRoot.toString(), rootIndex: Number(cmRootIdx), nextLeafIndex: Number(cmNext),
            subtreesHash: keccak256(toHex(JSON.stringify(cmSubtrees.map((x: bigint) => x.toString())))),
        },
        addressTree: { root: addrRoot.toString(), rootIndex: Number(addrRootIdx), nextLeafIndex: Number(addrNext) },
        revoker0: await read(POOL_PROXY, "getRevokerData", [0]).then((r: any) => JSON.stringify(r, (_, v) => typeof v === "bigint" ? v.toString() : v)),
        assets,
    };
};

// ---------------------------------------------------------------------------
// Probes: eth_call transactions that only the new code rejects with the new errors
// ---------------------------------------------------------------------------

const decodeRevert = (e: any): string => {
    if (e instanceof BaseError) {
        const r = e.walk(x => x instanceof ContractFunctionRevertedError) as ContractFunctionRevertedError | null;
        if (r?.data?.errorName) return `${r.data.errorName}(${(r.data.args ?? []).map(String).join(",")})`;
        const raw = (e.walk((x: any) => typeof x?.data === "string" && x.data.startsWith("0x")) as any)?.data;
        if (raw) {
            try {
                const d = decodeErrorResult({ abi: errorAbi, data: raw });
                return `${d.errorName}(${(d.args ?? []).map(String).join(",")})`;
            } catch { return `raw:${raw.slice(0, 10)}`; }
        }
    }
    return `unknown:${String(e?.shortMessage ?? e?.message ?? e).slice(0, 120)}`;
};

const callExpect = async (label: string, functionName: string, args: any[], expected: string, stateOverride?: any) => {
    let got: string;
    try {
        await client.simulateContract({
            address: POOL_PROXY, abi: [...poolAbi, ...errorAbi], functionName, args,
            account: "0x000000000000000000000000000000000000dEaD", stateOverride,
        });
        got = "success";
    } catch (e) {
        got = decodeRevert(e);
    }
    const ok = got === expected;
    console.log(`  ${ok ? "PASS" : "FAIL"}  ${label}\n        expected ${expected}\n        got      ${got}`);
    return ok;
};

const runProbes = async () => {
    const paused = await read(POOL_PROXY, "paused");
    // A paused pool reverts every probe with EnforcedPause; override the flag for the eth_call only.
    const stateOverride = paused ? [{ address: POOL_PROXY, stateDiff: [{ slot: PAUSABLE_SLOT, value: pad("0x0") }] }] : undefined;
    if (paused) console.log("  (pool is paused: probes run with an eth_call state override that unpauses)");

    const [, , cmRoot] = await read(POOL_PROXY, "getCommitmentTreeState");
    const [, addrRoot] = await read(POOL_PROXY, "getAddressTreeState");
    let revokerId = -1;
    for (let i = 0; i < 16 && revokerId < 0; i++) {
        const r: any = await read(POOL_PROXY, "getRevokerData", [i]);
        if (r.isActive) revokerId = i;
    }
    if (revokerId < 0) throw new Error("no active revoker; probes need one to reach the new checks");
    const pm = OLD_PAYMASTERS[0] ?? "0x000000000000000000000000000000000000fEE1";
    const base = {
        txType: 1, revokerId, addressTreeRoot: addrRoot, commitmentTreeRoot: cmRoot,
        feeData: 0n, refundAddress: 0n, betaUHF: 0n, pubAssets: [] as bigint[],
        nullifiers: [1n], commitments: [1n], proof: "0x" as Hex, assetsMemo: "0x" as Hex,
        keysMemo: "0x" as Hex, notesMemo: "0x" as Hex, targetData: "0x" as Hex,
    };
    // Default: 20 USDC on Ethereum (asset 65538), inside the $10..$250 bounds at any ETH price.
    const depositAsset = BigInt(process.env.PROBE_DEPOSIT_ASSET_ID ?? "65538");
    const depositAmount = BigInt(process.env.PROBE_DEPOSIT_AMOUNT ?? "20000000");
    const depth = Number(((poolAbi.find((x: any) => x.name === "updateCommitmentTree") as any)
        .inputs[0].components.find((c: any) => c.name === "newLevelSubtrees").type as string).match(/\[(\d+)\]/)![1]);

    const results = [
        await callExpect("nullifier n + p is rejected (double-spend fix)", "transact",
            [{ ...base, nullifiers: [FIELD_SIZE + 1n] }], `NonCanonicalFieldElement(${FIELD_SIZE + 1n})`, stateOverride),
        await callExpect("commitment c + p is rejected (tree-freeze fix)", "transact",
            [{ ...base, commitments: [FIELD_SIZE + 7n] }], `NonCanonicalFieldElement(${FIELD_SIZE + 7n})`, stateOverride),
        await callExpect("fee larger than the public amount is rejected (fee-mint fix)", "transact",
            [{
                ...base, txType: 2,
                pubAssets: [(65537n << 224n) | 1n],
                feeData: (BigInt(pm) << 96n) | (65537n << 72n) | 2n,
            }], "UnbackedFee(65537,2)", stateOverride),
        await callExpect("DEPOSIT with a fee is rejected (fee-mint fix)", "transact",
            [{
                // Must sit inside the pool's min/max deposit USD bounds or the guard rails revert first.
                ...base, txType: 0, nullifiers: [],
                pubAssets: [(depositAsset << 224n) | depositAmount],
                feeData: (BigInt(pm) << 96n) | (depositAsset << 72n) | 1n,
            }], `UnbackedFee(${depositAsset},1)`, stateOverride),
        await callExpect("batchSize = 0 tree update is rejected (root-eviction fix)", "updateCommitmentTree",
            [{ newRoot: 1n, batchSize: 0, newLevelSubtrees: Array(depth).fill(0n), proof: "0x" }], "InvalidBatchSize()", stateOverride),
        await callExpect("withdrawPaymasterFeeFor exists and is owner-only", "withdrawPaymasterFeeFor",
            [pm, 65537, "0x000000000000000000000000000000000000dEaD"], "OwnableUnauthorizedAccount(0x000000000000000000000000000000000000dEaD)", stateOverride),
    ];
    return results.every(Boolean);
};

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

const currentImpl = async (): Promise<Addr> =>
    getAddress("0x" + (await client.getStorageAt({ address: POOL_PROXY, slot: IMPL_SLOT })).slice(26)) as Addr;

const plan = async () => {
    const impl = await currentImpl();
    const { found, unmatched } = await identifyLinkedLibs(impl);
    console.log("Pool proxy          :", POOL_PROXY);
    console.log("Current impl        :", impl);
    console.log("Reused libraries (executable code identical to this build):", found);
    console.log("Replaced libraries (old QueuedMerkleTreeLogic / ShieldedTransactionLogic):", unmatched);
    for (const l of ["AssetLogic", "MerkleTreeLogic", "ShieldedAddressLogic"] as const) {
        if (!found[l]) throw new Error(`could not identify the live ${l}; its source may differ from this build`);
    }
    const libs = found as Libs;
    const snap = await snapshot(OLD_PAYMASTERS);
    console.log("State               :", JSON.stringify(snap, null, 2));
    for (const pm of OLD_PAYMASTERS) {
        console.log(`Old paymaster ${pm}: owner ${await read(pm, "owner", [], paymasterAbi)}, ` +
            `EntryPoint deposit ${await read(pm, "getEntryPointDeposit", [], paymasterAbi)} wei`);
    }
    return { impl, libs, snap, unmatched };
};

const deploy = async () => {
    const { impl, libs, snap, unmatched } = await plan();
    const [wallet] = await hre.viem.getWalletClients();
    console.log("\nDeployer:", wallet.account.address);

    // Reused as-is (unchanged source): AssetLogic, MerkleTreeLogic, ShieldedAddressLogic.
    const qmt = await hre.viem.deployContract("QueuedMerkleTreeLogic", []);
    console.log("QueuedMerkleTreeLogic   :", qmt.address);
    const stl = await hre.viem.deployContract("ShieldedTransactionLogic", [], {
        libraries: { AssetLogic: libs.AssetLogic, MerkleTreeLogic: libs.MerkleTreeLogic, QueuedMerkleTreeLogic: qmt.address },
    });
    console.log("ShieldedTransactionLogic:", stl.address);
    const newLibs: Libs = { ...libs, QueuedMerkleTreeLogic: qmt.address, ShieldedTransactionLogic: stl.address };
    const poolImpl = await hre.viem.deployContract("Pool", [], { libraries: newLibs });
    console.log("Pool implementation     :", poolImpl.address);

    const owner = snap.owner as Addr;
    const feeRecipient = (process.env.FEE_RECIPIENT ?? owner) as Addr;
    const nextVersion = BigInt(snap.version) + 1n;
    const tx = (to: Addr, abi: Abi, functionName: string, args: any[], note: string, from = owner) =>
        ({ note, from, to, value: "0", functionName, args: args.map(String), data: encodeFunctionData({ abi, functionName, args }) });

    const ownerTxs: any[] = [
        tx(POOL_PROXY, poolAbi, "pause", [], "Pause (pauser or owner). Skip if already paused.", snap.pauser as Addr),
        tx(POOL_PROXY, poolAbi, "upgradeToAndCall",
            [poolImpl.address, encodeFunctionData({ abi: poolAbi, functionName: "setVersion", args: [nextVersion] })],
            `Upgrade to the fixed implementation and set version ${nextVersion} in the same call.`),
    ];

    let newPaymaster: Addr | undefined;
    let newPaymasterOwner: Addr | undefined;
    if (OLD_PAYMASTERS.length) {
        // Replacement Paymaster, configured like the current one (OLD_PAYMASTERS[0]).
        const template = OLD_PAYMASTERS[0];
        newPaymasterOwner = (process.env.NEW_PAYMASTER_OWNER ?? owner) as Addr;
        const [ep, gw, th] = await Promise.all(["entryPoint", "sender", "priceStalenessThreshold"].map(f => read(template, f, [], paymasterAbi)));
        for (const pm of OLD_PAYMASTERS.slice(1)) {
            const cfg = await Promise.all(["entryPoint", "sender", "pool"].map(f => read(pm, f, [], paymasterAbi)));
            if (!isAddressEqual(cfg[0], ep) || !isAddressEqual(cfg[1], gw) || !isAddressEqual(cfg[2], POOL_PROXY)) {
                throw new Error(`old Paymaster ${pm} is configured differently from ${template}`);
            }
        }
        const pmC = await hre.viem.deployContract("Paymaster", [ep, gw, POOL_PROXY, th]);
        newPaymaster = pmC.address;
        console.log("New Paymaster           :", newPaymaster);
        const pub = await hre.viem.getPublicClient();
        for (const id of Object.keys(snap.assets)) {
            const feed = await read(template, "assetIdToChainlinkFeed", [Number(id)], paymasterAbi);
            const h = await wallet.writeContract({ address: newPaymaster, abi: paymasterAbi, functionName: "setChainlinkFeed", args: [Number(id), feed] });
            await pub.waitForTransactionReceipt({ hash: h });
        }
        const h = await wallet.writeContract({ address: newPaymaster, abi: paymasterAbi, functionName: "transferOwnership", args: [newPaymasterOwner] });
        await pub.waitForTransactionReceipt({ hash: h });

        for (const pm of OLD_PAYMASTERS) {
            for (const [id, a] of Object.entries<any>(snap.assets)) {
                const fee = a.paymasterFees[pm];
                if (BigInt(fee) > 0n) {
                    ownerTxs.push(tx(POOL_PROXY, poolAbi, "withdrawPaymasterFeeFor", [pm, Number(id), feeRecipient],
                        `Recover ${fee} of asset ${id} credited to old Paymaster ${pm}.`));
                }
            }
        }
        // Each old Paymaster's EntryPoint deposit is withdrawn by ITS owner. With no deposit it can
        // no longer sponsor anything, which retires it (it lacks the fee-paid check).
        for (const pm of OLD_PAYMASTERS) {
            const dep = await read(pm, "getEntryPointDeposit", [], paymasterAbi);
            const pmOwner = await read(pm, "owner", [], paymasterAbi) as Addr;
            if (dep > 0n) {
                ownerTxs.push(tx(pm, paymasterAbi, "withdrawFromEntryPoint", [pmOwner, dep],
                    `Retire old Paymaster ${pm}: withdraw its EntryPoint deposit (${dep} wei) to its owner. ` +
                    `Then fund the new Paymaster with depositToEntryPoint() (anyone can).`, pmOwner));
            }
        }
    }
    ownerTxs.push(tx(POOL_PROXY, poolAbi, "unpause", [], "Unpause (owner only) AFTER `UPGRADE_STEP=verify` passes."));

    const record = {
        chainId, poolProxy: POOL_PROXY, previousImplementation: impl, previousLibraries: { reused: libs, replaced: unmatched },
        newImplementation: poolImpl.address, newLibraries: newLibs,
        oldPaymasters: OLD_PAYMASTERS, newPaymaster: newPaymaster ?? null, newPaymasterOwner: newPaymasterOwner ?? null,
        expectedVersion: nextVersion.toString(), preUpgradeState: snap, ownerTransactions: ownerTxs,
        deployedAt: new Date().toISOString(),
    };
    fs.mkdirSync(path.dirname(outFile()), { recursive: true });
    fs.writeFileSync(outFile(), JSON.stringify(record, null, 2));
    console.log("\nWrote", outFile());
    console.log("\nPrivileged transactions, in order (check `from` for each: pauser, pool owner, or an old Paymaster's owner):");
    ownerTxs.forEach((t, i) => console.log(`\n[${i + 1}] ${t.note}\n    from ${t.from}\n    cast send ${t.to} ${t.data} --ledger --rpc-url $RPC`));
    return record;
};

const verify = async () => {
    const rec = JSON.parse(fs.readFileSync(outFile(), "utf8"));
    let ok = true;
    const check = (label: string, cond: boolean, detail = "") => {
        console.log(`  ${cond ? "PASS" : "FAIL"}  ${label}${detail ? "  " + detail : ""}`);
        ok &&= cond;
    };
    console.log("Bytecode (on-chain vs this build):");
    const nl = rec.newLibraries as Libs;
    check("QueuedMerkleTreeLogic", await matchesBuild(nl.QueuedMerkleTreeLogic, "QueuedMerkleTreeLogic", {}, "library"));
    check("ShieldedTransactionLogic", await matchesBuild(nl.ShieldedTransactionLogic, "ShieldedTransactionLogic", nl, "library"));
    check("Pool implementation", await matchesBuild(rec.newImplementation, "Pool", nl, "contract"));
    if (rec.newPaymaster) {
        const [ep, gw, pl] = await Promise.all(["entryPoint", "sender", "pool"].map(f => read(rec.newPaymaster, f, [], paymasterAbi)));
        check("new Paymaster", await matchesBuild(rec.newPaymaster, "Paymaster", {}, "contract", false, [ep, gw, pl]));
        check("new Paymaster owner", isAddressEqual(await read(rec.newPaymaster, "owner", [], paymasterAbi), rec.newPaymasterOwner));
        const tmpl = rec.oldPaymasters[0] as Addr;
        for (const f of ["entryPoint", "sender", "priceStalenessThreshold"]) {
            check(`new Paymaster ${f} = current Paymaster's`, String(await read(rec.newPaymaster, f, [], paymasterAbi)) === String(await read(tmpl, f, [], paymasterAbi)));
        }
        check("new Paymaster pool = proxy", isAddressEqual(await read(rec.newPaymaster, "pool", [], paymasterAbi), POOL_PROXY));
    }

    console.log("Proxy:");
    const impl = await currentImpl();
    if (isAddressEqual(impl, rec.previousImplementation)) {
        // Run between `deploy` and the owner's upgrade: lets the signer confirm what they are
        // about to point the proxy at before signing anything.
        console.log(`  INFO  proxy still points at the previous implementation ${impl}: pre-upgrade check only`);
        console.log(ok ? "\nPRE-UPGRADE CHECK OK: safe to sign the owner transactions" : "\nPRE-UPGRADE CHECK FAILED: do not upgrade");
        if (!ok) process.exitCode = 1;
        return ok;
    }
    check("implementation slot", isAddressEqual(impl, rec.newImplementation), impl);
    const cur = await snapshot(rec.oldPaymasters);
    check("version", cur.version === rec.expectedVersion, cur.version);

    console.log("Preserved state:");
    const pre = rec.preUpgradeState;
    check("owner", cur.owner === pre.owner);
    check("pauser", cur.pauser === pre.pauser);
    check("verifier", cur.verifier === pre.verifier);
    check("address tree", JSON.stringify(cur.addressTree) === JSON.stringify(pre.addressTree));
    check("revoker 0", cur.revoker0 === pre.revoker0);
    // Tree and balances move with user activity if the pool was not paused — reported, not failed.
    const same = (a: any, b: any) => JSON.stringify(a) === JSON.stringify(b);
    console.log(`  ${same(cur.commitmentTree, pre.commitmentTree) ? "PASS" : "INFO"}  commitment tree ${same(cur.commitmentTree, pre.commitmentTree) ? "unchanged" : "changed (user activity?)"}`);
    for (const [id, a] of Object.entries<any>(pre.assets)) {
        const c = cur.assets[id];
        check(`asset ${id} registered`, !!c && c.address === a.address && c.active === a.active);
        if (!c) continue;
        let recovered = 0n;
        for (const pm of rec.oldPaymasters) recovered += BigInt(a.paymasterFees[pm]) - BigInt(c.paymasterFees[pm]);
        const expectedBal = BigInt(a.balance) - recovered;
        const bal = BigInt(c.balance);
        console.log(`  ${bal === expectedBal ? "PASS" : "INFO"}  asset ${id} balance ${bal} (pre ${a.balance}, fees recovered ${recovered})`);
        check(`asset ${id} withdraw fees`, c.withdrawFees === a.withdrawFees);
    }
    for (const pm of rec.oldPaymasters) {
        const dep = await read(pm, "getEntryPointDeposit", [], paymasterAbi);
        console.log(`  ${dep === 0n ? "PASS" : "INFO"}  old Paymaster ${pm} EntryPoint deposit ${dep}${dep === 0n ? " (retired)" : " — still able to sponsor ops"}`);
    }

    console.log("Probes (eth_call, nothing is sent):");
    ok = (await runProbes()) && ok;
    console.log(ok ? "\nVERIFY OK" : "\nVERIFY FAILED");
    if (!ok) process.exitCode = 1;
    return ok;
};

const rehearse = async () => {
    if (!isLocal()) {
        throw new Error("rehearse impersonates the owner and only runs against a local fork");
    }
    console.log("== Probes BEFORE the upgrade (expect FAILs: the old code does not have the checks) ==");
    await runProbes();

    console.log("\n== Deploy ==");
    const rec = await deploy();

    console.log("\n== Owner transactions (impersonated) ==");
    const pub = await hre.viem.getPublicClient();
    for (const t of rec.ownerTransactions) {
        await client.request({ method: "anvil_impersonateAccount", params: [t.from] });
        await client.request({ method: "anvil_setBalance", params: [t.from, toHex(100_000_000_000_000_000_000n)] });
        const w = await hre.viem.getWalletClient(t.from);
        const h = await w.sendTransaction({ to: t.to, data: t.data, account: t.from, chain: w.chain });
        const r = await pub.waitForTransactionReceipt({ hash: h });
        console.log(`  ${r.status === "success" ? "OK " : "ERR"}  ${t.functionName}  gas=${r.gasUsed}`);
        if (r.status !== "success") throw new Error(`owner tx ${t.functionName} reverted`);
        if (t.functionName === "withdrawFromEntryPoint" && rec.newPaymaster) {
            // The runbook's step 5b: whoever received the old deposit funds the new Paymaster.
            const amount = BigInt(t.args[1]);
            const h2 = await w.writeContract({ address: rec.newPaymaster, abi: paymasterAbi, functionName: "depositToEntryPoint", value: amount, account: t.from, chain: w.chain });
            await pub.waitForTransactionReceipt({ hash: h2 });
            console.log(`  OK   depositToEntryPoint(new Paymaster) ${amount} wei`);
        }
    }

    console.log("\n== Verify ==");
    const ok = await verify();
    if (rec.newPaymaster) {
        const dep = await read(rec.newPaymaster, "getEntryPointDeposit", [], paymasterAbi);
        console.log(`  new Paymaster EntryPoint deposit: ${dep}`);
    }
    return ok;
};

const main = async () => {
    if (!POOL_PROXY) throw new Error("POOL_PROXY is required");
    client = await hre.viem.getPublicClient();
    chainId = await client.getChainId();
    console.log(`network=${hre.network.name} chainId=${chainId} step=${step}\n`);
    if (step === "plan") await plan();
    else if (step === "deploy") await deploy();
    else if (step === "verify") await verify();
    else if (step === "rehearse") await rehearse();
    else throw new Error(`unknown UPGRADE_STEP ${step}`);
};

main().catch((e) => { console.error(e); process.exitCode = 1; });
