/**
 * End-to-end run against the HyperEVM testnet (998) public-input-cut pool, with real proofs
 * (dev keys from v1-circuits feat/hyperevm-input-cut) and real HyperEVM gas prices:
 *   register -> deposit (native HYPE) -> settle (our keeper) -> transfer -> settle -> withdraw
 * Prints gasUsed for every transaction type.
 *
 *   ADMIN_PK=0x.. E2E_CIRCUITS=../v1-circuits-inputcut/artifacts npx ts-node test/e2e/hyperevm998.e2e.ts
 *
 * The trees are rebuilt from the pool's events (RegisterAddress, Commitment), so the run does not
 * assume it is the only user. The test wallet's key and shielded seed are kept in E2E_STATE so a
 * rerun can continue.
 */
//@ts-ignore
import * as snarkJs from "snarkjs";
import { existsSync, readFileSync, writeFileSync } from "fs";
import {
  Hex, createPublicClient, createWalletClient, defineChain, http, parseEther, parseAbiItem, decodeFunctionData,
  zeroAddress, keccak256, stringToBytes, hexToBigInt, sliceHex, padHex, toHex,
} from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import MerkleTree from "fixed-merkle-tree";
import { Core } from "@veilnyx-sdk/core";
import { ShieldedAccount } from "@veilnyx-sdk/account";
import { fp, poseidonHash } from "@veilnyx-sdk/babyjubjub";
import { randomBigInt } from "@veilnyx-sdk/utils";
import { TransactionType, ITreeSource, INote } from "@veilnyx-sdk/shared-types";
import { Note, SIZE_ENCRYPTED_DECRYPTION_KEY, SIZE_FULLY_ENCRYPTED_NOTE_DATA } from "@veilnyx-sdk/transaction";
import { ZTransaction } from "@veilnyx-sdk/zk-prover";

const RPC = process.env.RPC ?? "https://rpc.hyperliquid-testnet.xyz/evm";
const POOL = (process.env.POOL ?? "0x957aBfFb86128c382f2f7247441391423792cB73") as Hex;
const PAYMASTER = "0xae51c21B7e3F43a44e1C548E35B952eEafE01268" as Hex;
const DEPLOY_BLOCK = BigInt(process.env.DEPLOY_BLOCK ?? 69527335);
const CIRCUITS = process.env.E2E_CIRCUITS as string;
const STATE = process.env.E2E_STATE as string;
const REVOKER_ID = 2;
const WHYPE = 65537;
const GAS_CAP = 2_950_000n;

const chain = defineChain({
  id: 998, name: "HyperEVM testnet", nativeCurrency: { name: "HYPE", symbol: "HYPE", decimals: 18 },
  rpcUrls: { default: { http: [RPC] } },
});
const pub = createPublicClient({ chain, transport: http(RPC, { retryCount: 9, retryDelay: 2000 }) });
const poolAbi = JSON.parse(readFileSync(process.env.POOL_ABI ?? "artifacts/src/core/Pool.sol/Pool.json", "utf8")).abi;
const ZERO = fp.create(BigInt(keccak256(stringToBytes("zero"))));
const zeroHex = padHex(toHex(ZERO), { size: 32 });
const hashFunction = (a: any, b: any) => padHex(toHex(poseidonHash([BigInt(a), BigInt(b)])), { size: 32 });
const log = (...a: any[]) => console.log(new Date().toISOString().slice(11, 19), ...a);
const gasReport: Record<string, bigint> = {};

// ---------------------------------------------------------------- chain reads

/// Incremental, rate-limit tolerant eth_getLogs: the public HyperEVM RPC caps a call at ~1000
/// blocks and rate-limits bursts, so each event's logs are cached and only new blocks fetched.
const logCache = new Map<string, { scanned: bigint; logs: any[] }>();
let persistLogs: () => void = () => {};
async function logs(event: any) {
  const key = event.name;
  const c = logCache.get(key) ?? { scanned: DEPLOY_BLOCK - 1n, logs: [] };
  const head = await pub.getBlockNumber();
  while (c.scanned < head) {
    const from = c.scanned + 1n;
    const to = from + 999n < head ? from + 999n : head;
    for (let attempt = 0; ; attempt++) {
      try {
        c.logs.push(...(await pub.getLogs({ address: POOL, event, fromBlock: from, toBlock: to })));
        break;
      } catch (e: any) {
        if (attempt >= 12) throw e;
        await new Promise((r) => setTimeout(r, 3000 * (attempt + 1)));
      }
    }
    c.scanned = to;
    logCache.set(key, c);
    persistLogs();
    await new Promise((r) => setTimeout(r, 2500));
  }
  logCache.set(key, c);
  return c.logs;
}

const commitmentEvent = parseAbiItem("event Commitment(uint256 indexed leafIndex, uint256 indexed commitment)");
const registerEvent = parseAbiItem("event RegisterAddress(address indexed publicAddress, uint256 indexed rootAddress, uint32 indexed leafIndex, bytes shieldedAddress)");

async function treeState() {
  const [queued, root, , next] = (await pub.readContract({ address: POOL, abi: poolAbi, functionName: "getCommitmentTreeState" })) as any;
  return { queued: (queued as bigint[]).filter((l) => l !== ZERO), root: root as bigint, next: Number(next) };
}

class EventTree implements ITreeSource {
  tree: MerkleTree;
  lastUpdatedLeafIndex: number;
  constructor(depth: number, leaves: bigint[]) {
    this.tree = new MerkleTree(depth, leaves.map((l) => padHex(toHex(l), { size: 32 })), { hashFunction, zeroElement: zeroHex });
    this.lastUpdatedLeafIndex = leaves.length - 1;
  }
  get root() { return BigInt(this.tree.root.toString()); }
  get depth() { return this.tree.levels; }
  get zeroLeaf() { return ZERO; }
  update() {}
  indexOf(leaf: bigint | Hex) { return this.tree.indexOf(padHex(toHex(BigInt(leaf)), { size: 32 })); }
  pathElements(i: number) { return this.tree.path(i).pathElements.map((e) => hexToBigInt(e.toString() as Hex)); }
}

class Notes {
  notes: INote[] = [];
  async getAll() { return this.notes; }
  async getUnspent() { return this.notes; }
  async checkSpent(): Promise<boolean[]> { throw new Error("n/a"); }
  async chooseForSpending(): Promise<INote[]> { throw new Error("n/a"); }
}

/// Settled commitments (leafIndex < nextLeafIndex), as the on-chain tree holds them.
async function commitmentTree() {
  const { next, root } = await treeState();
  const evs = await logs(commitmentEvent);
  const byIndex = new Map<number, bigint>(evs.map((e) => [Number(e.args.leafIndex), e.args.commitment as bigint]));
  const leaves: bigint[] = [];
  for (let i = 0; i < next; i++) {
    const c = byIndex.get(i);
    if (c === undefined) throw new Error(`missing commitment ${i}`);
    leaves.push(c);
  }
  const t = new EventTree(25, leaves);
  if (t.root !== root) throw new Error(`local commitment root ${t.root} != on-chain ${root}`);
  return { tree: t, byIndex };
}

async function addressTree() {
  const evs = (await logs(registerEvent)).sort((a, b) => Number(a.args.leafIndex) - Number(b.args.leafIndex));
  return new EventTree(20, evs.map((e) => e.args.rootAddress as bigint));
}

// ---------------------------------------------------------------- helpers

/// The transact arguments exactly as the pool received them (from the transaction's calldata).
async function onchainStx(hash: Hex) {
  const tx = await pub.getTransaction({ hash });
  return (decodeFunctionData({ abi: poolAbi, data: tx.input }) as any).args[0];
}

function decryptOwnNotes(ztx: any, account: ShieldedAccount, revoker: any, byIndex: Map<number, bigint>) {
  const [, ...keys] = splitChunks(ztx.keysMemo, SIZE_ENCRYPTED_DECRYPTION_KEY);
  const enc = splitChunks(sliceHex(ztx.notesMemo, 7 * 32), SIZE_FULLY_ENCRYPTED_NOTE_DATA);
  const out: any[] = [];
  enc.forEach((e, i) => {
    // toSolidityInput() carries commitments as hex strings
    const commitment = BigInt(ztx.commitments[i]);
    const leafIndex = [...byIndex.entries()].find(([, c]) => c === commitment)?.[0];
    if (leafIndex === undefined) return;
    const n = Note.decrypt(0, keys[i], e, { account, revoker, leafIndex } as any);
    if (n && n.value > 0n) out.push(n);
  });
  return out;
}

function splitChunks(data: Hex, size: number): Hex[] {
  const out: Hex[] = [];
  for (let i = 0; i < (data.length - 2) / 2; i += size) out.push(sliceHex(data, i, i + size));
  return out;
}

async function send(label: string, wallet: any, args: { functionName: string; args: any[]; value?: bigint }) {
  const est = await pub.estimateContractGas({ address: POOL, abi: poolAbi, account: wallet.account, ...args } as any);
  let gas = (est * 125n) / 100n;
  if (gas > GAS_CAP && est <= GAS_CAP) gas = GAS_CAP;
  const hash = await wallet.writeContract({ address: POOL, abi: poolAbi, chain, gas, ...args });
  for (let i = 0; ; i++) {
    try {
      const r = await pub.getTransactionReceipt({ hash });
      if (r.status !== "success") throw new Error(`${label} reverted: ${hash}`);
      log(`${label}: gasUsed ${r.gasUsed} (estimate ${est}, limit ${gas}) block ${r.blockNumber} ${hash}`);
      gasReport[label] = r.gasUsed;
      return r;
    } catch (e: any) {
      if (!/could not be found|not found/i.test(e?.message ?? "") || i > 120) throw e;
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
}

async function waitSettled(label: string) {
  const before = await treeState();
  if (before.queued.length === 0) return;
  log(`${label}: waiting for the keeper to settle ${before.queued.length} leaves...`);
  const nextBefore = before.next;
  for (let i = 0; i < 300; i++) {
    await new Promise((r) => setTimeout(r, 15000));
    const s = await treeState();
    if (s.next > nextBefore && s.queued.length === 0) {
      log(`${label}: settled, nextLeafIndex ${nextBefore} -> ${s.next}`);
      return;
    }
  }
  throw new Error("keeper did not settle within 25 minutes");
}

// ---------------------------------------------------------------- run

async function main() {
  if (!CIRCUITS || !STATE) throw new Error("E2E_CIRCUITS and E2E_STATE are required");
  const admin = privateKeyToAccount(process.env.ADMIN_PK as Hex);
  const state = existsSync(STATE) ? JSON.parse(readFileSync(STATE, "utf8")) : {};
  state.userKey ??= generatePrivateKey();
  state.seed ??= randomBigInt(31).toString();
  state.receiverSeed ??= randomBigInt(31).toString();
  const save = () => writeFileSync(STATE, JSON.stringify(state, (_, v) => (typeof v === "bigint" ? `bigint:${v}` : v), 2));
  // Resume the event scan where the last run stopped (the public RPC is heavily rate-limited).
  for (const [k, v] of Object.entries<any>(state.logCache ?? {})) {
    const revive = (x: any): any => typeof x === "string" && x.startsWith("bigint:") ? BigInt(x.slice(7))
      : Array.isArray(x) ? x.map(revive) : x && typeof x === "object" ? Object.fromEntries(Object.entries(x).map(([a, b]) => [a, revive(b)])) : x;
    logCache.set(k, { scanned: BigInt(v.scanned), logs: revive(v.logs) });
  }
  persistLogs = () => {
    state.logCache = Object.fromEntries([...logCache.entries()].map(([k, v]) => [k, { scanned: v.scanned.toString(), logs: v.logs.map((l) => ({ args: l.args })) }]));
    save();
  };
  save();

  const user = privateKeyToAccount(state.userKey);
  const wallet = createWalletClient({ account: user, chain, transport: http(RPC) });
  const account = ShieldedAccount.generate(BigInt(state.seed));
  const receiver = ShieldedAccount.generate(BigInt(state.receiverSeed));
  log(`user ${user.address}  shielded root ${account.rootAddress}`);

  if ((await pub.getBalance({ address: user.address })) < parseEther("0.8")) {
    const aw = createWalletClient({ account: admin, chain, transport: http(RPC) });
    const h = await aw.sendTransaction({ to: user.address, value: parseEther("1.2"), chain });
    await pub.waitForTransactionReceipt({ hash: h });
    log("funded user with 1.2 HYPE");
  }

  const circuits: Record<string, any> = {};
  for (const c of ["register", "treeUpdate", "transact21", "transact22", "transact23", "transact42", "transact44", "transact82", "transact84"]) {
    circuits[c] = { zKey: `${CIRCUITS}/${c}/keys.zkey`, wasm: `${CIRCUITS}/${c}/circuit.wasm`, vKey: `${CIRCUITS}/${c}/vKey.json` };
  }
  const notes = new Notes();
  const build = async () => {
    const [addr, cm] = await Promise.all([addressTree(), commitmentTree()]);
    const sdk = new Core({
      chainId: 998, account, rpc: pub as any, explorerApi: "",
      contracts: { pool: POOL, paymaster: PAYMASTER, deployedBlock: DEPLOY_BLOCK } as any,
      circuits, snarkJs,
      services: { commitmentTreeSource: cm.tree, addressTreeSource: addr, notesSource: notes as any, contractSource: {} as any },
    } as any);
    return { sdk, byIndex: cm.byIndex, addr };
  };
  const revoker = (await (await build()).sdk.getRevokerData(REVOKER_ID)) as any;

  // 1. register
  let { sdk, addr } = await build();
  if (addr.indexOf(account.rootAddress) < 0) {
    const reg = await sdk.proveAddress("0x", user.address);
    const sol: any = reg.toSolidityInput();
    const [, name, version] = (await pub.readContract({ address: POOL, abi: poolAbi, functionName: "eip712Domain" })) as any;
    const signature = await wallet.signTypedData({
      domain: { name, version, chainId: 998, verifyingContract: POOL },
      types: { RegisterAddress: [{ name: "message", type: "string" }, { name: "shieldedAddress", type: "bytes" }] },
      primaryType: "RegisterAddress",
      message: { message: "Register Shielded Address", shieldedAddress: sol.shieldedAddress },
    });
    await send("register", wallet, { functionName: "registerAddress", args: [{ ...sol, signature }] });
  } else log("already registered");

  // 2. deposit 0.5 HYPE (native, wrapped by the pool); reuse a recorded deposit on reruns
  if (!state.depositTx) {
    ({ sdk } = await build());
    const depositValue = parseEther("0.5");
    const depTx = await sdk.createTransaction(
      { type: TransactionType.DEPOSIT, assetIds: [WHYPE], values: [depositValue], feeAssetId: 0, to: account.shieldedAddress.pack() },
      { revokerId: REVOKER_ID, viaBundler: false, paymaster: zeroAddress },
    );
    const depZ = await sdk.proveTransaction(await sdk.signTransaction(depTx));
    const depRc = await send("deposit", wallet, { functionName: "transact", args: [depZ.toSolidityInput()], value: depositValue });
    state.depositTx = depRc.transactionHash;
    save();
  } else log(`reusing deposit ${state.depositTx}`);
  await waitSettled("deposit");

  // 3. transfer 0.2 HYPE to another shielded account
  let byIndex: Map<number, bigint>;
  ({ sdk, byIndex } = await build());
  notes.notes = decryptOwnNotes(await onchainStx(state.depositTx), account, revoker.revokerPublicKey, byIndex);
  log(`spendable notes: ${notes.notes.map((n: any) => `${n.value}@${n.leafIndex}`).join(", ")}`);
  const trTx = await sdk.createTransaction(
    { type: TransactionType.TRANSFER, assetIds: [WHYPE], values: [parseEther("0.2")], feeAssetId: 0, to: receiver.shieldedAddress.pack() },
    { revokerId: REVOKER_ID, viaBundler: false, paymaster: zeroAddress },
  );
  const trZ = await sdk.proveTransaction(await sdk.signTransaction(trTx));
  const trRc = await send("transfer", wallet, { functionName: "transact", args: [trZ.toSolidityInput()] });
  state.transferTx = trRc.transactionHash;
  save();
  await waitSettled("transfer");

  // 4. withdraw 0.1 HYPE (from the change note) to the user's EOA
  ({ sdk, byIndex } = await build());
  notes.notes = decryptOwnNotes(await onchainStx(state.transferTx), account, revoker.revokerPublicKey, byIndex);
  log(`spendable notes: ${notes.notes.map((n: any) => `${n.value}@${n.leafIndex}`).join(", ")}`);
  const wdTx = await sdk.createTransaction(
    { type: TransactionType.WITHDRAW, assetIds: [WHYPE], values: [parseEther("0.1")], feeAssetId: 0, to: user.address },
    { revokerId: REVOKER_ID, viaBundler: false, paymaster: zeroAddress },
  );
  const wdZ = await sdk.proveTransaction(await sdk.signTransaction(wdTx));
  const wdRc = await send("withdraw", wallet, { functionName: "transact", args: [wdZ.toSolidityInput()] });
  state.withdrawTx = wdRc.transactionHash;
  save();

  log("GAS (HyperEVM testnet, real prices):", Object.fromEntries(Object.entries(gasReport).map(([k, v]) => [k, v.toString()])));
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
