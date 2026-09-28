import { Hex, parseAbi } from "viem";
import { ChainParams, isUnconfigured } from "../configs";

/** HyperEVM mainnet. */
export const HYPEREVM_MAINNET_CHAIN_ID = 999;

/**
 * The tightest staleness threshold any deployed contract applies to these feeds:
 * Paymaster's PRICEFEED_STALENESS_THRESHOLD (erc4337Infra.ts, 24h) — the pool's is 30h.
 * A feed older than this at deploy time would revert fee conversion on the first user op.
 */
const MAX_FEED_AGE_SECONDS = 24 * 60 * 60;

const erc20Abi = parseAbi(["function decimals() view returns (uint8)"]);
const aggregatorAbi = parseAbi([
  "function decimals() view returns (uint8)",
  "function description() view returns (string)",
  "function latestRoundData() view returns (uint80, int256, uint256, uint256, uint80)",
]);

/**
 * Checks specific to deploying on HyperEVM mainnet. Runs before anything costs gas.
 *
 * 1. Sanctions screening is an explicit decision. Chainalysis' oracle does not exist on
 *    HyperEVM, and a zero `sanctionsList` silently disables screening (Pool._setScreener's
 *    documented kill switch). So a zero address must be paired with `screeningDisabled: true`
 *    in config.json — a reviewed, committed decision — and a non-zero one must not be.
 *
 * 2. Every base asset's on-chain `decimals()` equals its configured precision. On HyperEVM the
 *    USDC that spotMeta lists (0x6b9e77…0a24) is the Core bridge SINK, not a token: every call on
 *    it reverts, and its "8 decimals" are HyperCore's. The pool asset is Circle USDC, 6 decimals.
 *    Registering the wrong one is not repairable in place (the asset counter only moves forward).
 *
 * 3. Every configured price feed answers, reports a positive price, and is fresher than the
 *    tightest staleness threshold the contracts will enforce.
 *
 * 4. Live runs only: the deployer has HyperEVM "big blocks" enabled. Small blocks cap a
 *    transaction at a few million gas, below what the Pool implementation and the verifiers need
 *    to deploy, so a run without them stops midway — which leaves a pool that has to be redeployed.
 *    Big blocks are switched on per account from HyperCore (an `evmUserModify` action signed by
 *    the deployer key, which must already be a HyperCore user); anvil forks have no such concept,
 *    so dry runs skip this check.
 */
export const assertHyperEvmReady = async (params: {
  client: any;
  chainParams: ChainParams & { screeningDisabled?: boolean };
  deployer: Hex;
  dryRun: boolean;
}) => {
  const { client, chainParams, deployer, dryRun } = params;
  const errors: string[] = [];

  // 1. Screening decision
  const screenerUnset = isUnconfigured(chainParams.sanctionsList);
  if (screenerUnset && chainParams.screeningDisabled !== true) {
    errors.push(
      `sanctionsList is the zero address, which disables sanctions screening. Set a screener ` +
      `contract, or record the decision with "screeningDisabled": true in config.json`
    );
  }
  if (!screenerUnset && chainParams.screeningDisabled === true) {
    errors.push(`config.json sets both a sanctionsList and "screeningDisabled": true — pick one`);
  }
  if (!screenerUnset) {
    const code = await client.getCode({ address: chainParams.sanctionsList });
    if (!code || code === "0x") {
      errors.push(`sanctionsList ${chainParams.sanctionsList} has no code — Pool rejects an EOA screener`);
    }
  }

  // 2. Asset decimals vs configured precision
  for (let i = 0; i < chainParams.initAssetAddresses.length; i++) {
    const asset = chainParams.initAssetAddresses[i];
    try {
      const decimals = Number(
        await client.readContract({ address: asset, abi: erc20Abi, functionName: "decimals" })
      );
      if (decimals !== chainParams.initAssetsPrecision[i]) {
        errors.push(
          `initAssetAddresses[${i}] ${asset} has decimals() = ${decimals}, config precision is ` +
          `${chainParams.initAssetsPrecision[i]}`
        );
      }
    } catch {
      errors.push(
        `initAssetAddresses[${i}] ${asset}: decimals() reverted — not a token (the HyperCore USDC ` +
        `bridge sink 0x6b9e77…0a24 behaves exactly like this; the pool asset is Circle USDC)`
      );
    }
  }

  // 3. Price feeds
  const feeds = new Set<string>(
    [...chainParams.initAssetToUSDChainlinkFeeds, ...chainParams.initNativeGasTokenToAssetChainlinkFeeds]
      .filter((f) => !isUnconfigured(f))
      .map((f) => f.toLowerCase())
  );
  const now = BigInt(Math.floor(Date.now() / 1000));
  for (const feed of feeds) {
    try {
      const [description, decimals, round] = await Promise.all([
        client.readContract({ address: feed as Hex, abi: aggregatorAbi, functionName: "description" }),
        client.readContract({ address: feed as Hex, abi: aggregatorAbi, functionName: "decimals" }),
        client.readContract({ address: feed as Hex, abi: aggregatorAbi, functionName: "latestRoundData" }),
      ]);
      const [, answer, , updatedAt] = round as [bigint, bigint, bigint, bigint, bigint];
      const age = now - updatedAt;
      console.log(
        `  feed ${feed} "${description}": ${Number(answer) / 10 ** Number(decimals)} ` +
        `(${decimals} dec), ${age / 60n} min old`
      );
      if (answer <= 0n) errors.push(`feed ${feed} (${description}) reports a non-positive price`);
      if (age > BigInt(MAX_FEED_AGE_SECONDS)) {
        errors.push(`feed ${feed} (${description}) is ${age}s old, above the ${MAX_FEED_AGE_SECONDS}s the Paymaster allows`);
      }
    } catch (e: any) {
      errors.push(`feed ${feed}: not an AggregatorV3 feed or not answering (${e.shortMessage ?? e.message})`);
    }
  }

  // 4. Big blocks (live only)
  if (!dryRun) {
    const usingBigBlocks = await client.request({
      method: "eth_usingBigBlocks" as any,
      params: [deployer] as any,
    });
    if (usingBigBlocks !== true) {
      errors.push(
        `deployer ${deployer} does not have big blocks enabled. Enable them from HyperCore ` +
        `(evmUserModify { usingBigBlocks: true }, signed by the deployer, which must be a HyperCore ` +
        `user) — see docs/hyperevm-mainnet-deployment.md`
      );
    }
  }

  if (errors.length > 0) {
    throw new Error(
      `HyperEVM preflight failed — nothing has been deployed:\n` + errors.map((e) => `  - ${e}`).join("\n")
    );
  }
  if (screenerUnset) {
    console.warn("⚠️  Sanctions screening is DISABLED on this pool (config: screeningDisabled = true)");
  }
  console.log(`HyperEVM preflight passed${dryRun ? " (dry run: big-blocks check skipped)" : ""}`);
};
