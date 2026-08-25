import hre from "hardhat";
import { Hex, isAddressEqual, zeroAddress } from "viem";

/**
 * A deployed contract whose ownership should end up with the protocol owner
 * (hardware wallet / multisig) instead of the deployer key from `.env.PRIVATE_KEY`.
 */
export type OwnableContract = {
    /** Hardhat artifact name — used to read the `owner()` / `transferOwnership()` ABI. */
    contract: string;
    /** Address the ABI is called against. For proxies this is the proxy address. */
    address: Hex;
    /** Log label. Defaults to `contract`. Useful when the ABI name differs from the deployment (e.g. Pool/PoolProxy). */
    label?: string;
};

export type OwnershipTransferStatus =
    /** `transferOwnership` was broadcast and `owner()` now reads back as the new owner. */
    | "transferred"
    /** Nothing to do — `owner()` already is the new owner. */
    | "already-owned"
    /** Deliberately not attempted (no owner configured). */
    | "skipped"
    /** Attempted (or pre-checked) and the contract is NOT owned by the new owner. */
    | "failed";

export type OwnershipTransferResult = {
    label: string;
    address: Hex;
    status: OwnershipTransferStatus;
    /** Owner as read back from chain after the attempt. `zeroAddress` when it could not be read. */
    owner: Hex;
    /** Why the transfer was skipped or failed. */
    reason?: string;
};

/**
 * Loosely typed view of hardhat-viem's `DeployContractConfig`. `KeyedClient` marks both
 * clients optional, so this keeps the helper callable with the same `deployConfig` object
 * the deploy scripts already thread around without fighting the union type.
 */
export type OwnershipDeployConfig = {
    client?: {
        public?: any;
        wallet?: any;
    };
};

const isUnset = (address?: Hex) =>
    !address || isAddressEqual(address, zeroAddress);

/**
 * Transfers ownership of every supplied contract from the deployer to `newOwner`.
 *
 * Call this once, after all owner-gated post-deployment setup is done — every
 * `onlyOwner` call made afterwards with the deployer key will revert.
 *
 * The helper is idempotent and safe to re-run: contracts already owned by `newOwner`
 * are reported as `already-owned` and left untouched, so a partially completed run can
 * simply be repeated. It never throws on a single failure — it reports every contract so
 * one bad transfer does not hide the state of the rest. Pair it with
 * {@link assertOwnershipTransferred} to fail the deployment once the summary is printed.
 *
 * @param contracts Contracts to hand over. Non-Ownable contracts must not be listed.
 * @param newOwner  Intended owner (hardware wallet / multisig). `zeroAddress` or
 *                  `undefined` skips every transfer and retains deployer ownership,
 *                  which is the intended behaviour for local/testing deployments.
 *                  Note: OZ v5 `transferOwnership(address(0))` reverts, so the skip is
 *                  the only way to express "keep it with the deployer".
 * @param deployConfig The `{ client: { public, wallet } }` config used for the deployment.
 */
export const transferOwnershipToOwner = async (
    contracts: OwnableContract[],
    newOwner: Hex,
    deployConfig: OwnershipDeployConfig
): Promise<OwnershipTransferResult[]> => {
    const publicClient = deployConfig.client?.public;
    const wallet = deployConfig.client?.wallet;

    if (!publicClient || !wallet) {
        throw new Error(
            "transferOwnershipToOwner: deployConfig.client must carry both a public and a wallet client"
        );
    }

    const deployer = wallet.account.address as Hex;

    if (isUnset(newOwner)) {
        console.warn(
            `⚠️  Ownership transfer skipped for ${contracts.length} contract(s): no owner configured (common.hardwareWalletOwner is unset/zero). Ownership stays with the deployer ${deployer}.`
        );
        return contracts.map((c) => ({
            label: c.label ?? c.contract,
            address: c.address,
            status: "skipped" as const,
            owner: deployer,
            reason: "no owner configured",
        }));
    }

    console.log(`\nTransferring ownership to ${newOwner} (deployer: ${deployer})`);

    const results: OwnershipTransferResult[] = [];

    // Sequential on purpose: these all go out from the same deployer account, and
    // parallel writes would race on the nonce.
    for (const { contract, address, label: contractLabel } of contracts) {
        const label = contractLabel ?? contract;
        const abi = hre.artifacts.readArtifactSync(contract).abi;

        const readOwner = async () =>
            (await publicClient.readContract({
                address,
                abi,
                functionName: "owner",
            })) as Hex;

        try {
            const currentOwner = await readOwner();

            if (isAddressEqual(currentOwner, newOwner)) {
                console.log(`✅ ${label} (${address}): already owned by ${newOwner}`);
                results.push({ label, address, status: "already-owned", owner: currentOwner });
                continue;
            }

            if (!isAddressEqual(currentOwner, deployer)) {
                const reason = `owned by ${currentOwner}, deployer ${deployer} cannot transfer it`;
                console.error(`❌ ${label} (${address}): ${reason}`);
                results.push({ label, address, status: "failed", owner: currentOwner, reason });
                continue;
            }

            const hash = await wallet.writeContract({
                address,
                abi,
                functionName: "transferOwnership",
                args: [newOwner],
            });
            const rct = await publicClient.waitForTransactionReceipt({ hash });

            if (rct.status !== "success") {
                const reason = `transferOwnership tx reverted (${hash})`;
                console.error(`❌ ${label} (${address}): ${reason}`);
                results.push({ label, address, status: "failed", owner: currentOwner, reason });
                continue;
            }

            // Read back rather than trusting the receipt: the ABI could belong to a
            // contract that overrides transferOwnership, and on a mainnet handover the
            // on-chain owner is the only answer worth reporting.
            const updatedOwner = await readOwner();
            if (!isAddressEqual(updatedOwner, newOwner)) {
                const reason = `owner() still reads ${updatedOwner} after transferOwnership (${hash})`;
                console.error(`❌ ${label} (${address}): ${reason}`);
                results.push({ label, address, status: "failed", owner: updatedOwner, reason });
                continue;
            }

            console.log(`✅ ${label} (${address}): ownership transferred to ${newOwner}`);
            results.push({ label, address, status: "transferred", owner: updatedOwner });
        } catch (error) {
            const reason = error?.message ?? String(error);
            console.error(`❌ ${label} (${address}): ownership transfer failed — ${reason}`);
            results.push({ label, address, status: "failed", owner: zeroAddress, reason });
        }
    }

    logOwnershipSummary(results);

    return results;
};

/** Prints a per-contract table of the ownership handover. */
export const logOwnershipSummary = (results: OwnershipTransferResult[]) => {
    console.log("\n--- Ownership summary ---");
    for (const { label, address, status, owner, reason } of results) {
        const icon = status === "failed" ? "❌" : status === "skipped" ? "⚠️ " : "✅";
        console.log(
            `${icon} ${label.padEnd(20)} ${address} owner=${owner} [${status}]${reason ? ` — ${reason}` : ""}`
        );
    }
    console.log("-------------------------\n");
};

/**
 * Throws if any contract failed to hand over ownership. Call at the very end of a
 * deployment so a failed handover is loud and the run exits non-zero, without aborting
 * the steps (e.g. Etherscan verification) that follow the transfer.
 */
export const assertOwnershipTransferred = (results: OwnershipTransferResult[]) => {
    const failed = results.filter((r) => r.status === "failed");
    if (failed.length === 0) return;

    throw new Error(
        `Ownership transfer failed for ${failed.length} contract(s) — these are still controlled by the deployer key:\n` +
        failed.map((f) => `  - ${f.label} (${f.address}): ${f.reason}`).join("\n")
    );
};
