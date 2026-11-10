import hre from "hardhat";
import {
  encodeFunctionData,
  isAddressEqual,
  formatEther,
  parseEther,
  Hex,
} from "viem";

import { DeployContractConfig, KeyedClient } from '@nomicfoundation/hardhat-viem/types';
import {
  loadConfigs,
  ChainParams,
  AdaptorParams,
  CommonParams,
  assertChainAssetConfig,
  isUnconfigured,
  GAS_ASSET_ID,
} from "./configs";
import { deployHasher } from "./hasher";
import { deployVerifier } from "./verifier";
import { getChainForCurrentNetwork, isDevelopmentNode } from "./utils/chainUtils";
import { assertVerifiersMatchCeremony } from "./utils/verifierProvenance";
import {
  assertRevokerMetadata,
  checkRevokerMetadataIsPinned,
  encodeRevokerMetadata,
} from "./utils/revokerMetadata";
import { assertOwnershipTransferred, transferOwnershipToOwner } from "./utils/ownership";
import { deployErc4337Infra } from "./erc4337Infra";
import { RecordTarget, assertRecordWritable, writeRecord } from "./utils/deploymentRecord";
import {
  VerifyResult,
  VerifyTarget,
  linkProxyOnEtherscan,
  printVerifySummary,
  verifyOnEtherscan,
} from "./utils/etherscanVerify";

const config = loadConfigs();

// ABIs
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const adaptorHandlerAbi = hre.artifacts.readArtifactSync("AdaptorHandler").abi;

// Prints in bold red so a failure does not get lost in the surrounding deploy output.
// Only the reporting-style steps (Etherscan verification, ownership summary) keep going
// after logging; every state-changing setup call below aborts the run instead.
const logError = (...args: any[]) => console.error("\x1b[1;31m✖", ...args, "\x1b[0m");

const deployUniswap = async (uniswapParams, pool, deployConfig) => {
  const uniswap = await hre.viem.deployContract("UniswapV3Adapter", [
    uniswapParams.uniswapSwapRouter02,
    pool
  ], deployConfig)
  console.log("UniswapV3Adapter deployed:", uniswap.address);
  await addAdpatorSupport(pool, uniswap.address, true, deployConfig.client.wallet, deployConfig.client.public);
  return uniswap.address;
}

const deployAave = async (aaveParams, pool, deployConfig) => {
  const aave = await hre.viem.deployContract("AaveV3Adaptor", [
    aaveParams.aave,
    pool,
    aaveParams.aaveStaticTokenFactory
  ], deployConfig);
  console.log("AaveV3Adapter deployed:", aave.address);
  await addAdpatorSupport(pool, aave.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [aaveParams.assets.staticAWeth, aaveParams.assets.staticAUsdc];
  const assetsPrecision = [aaveParams.assetsPrecision.staticAWeth, aaveParams.assetsPrecision.staticAUsdc];
  const assetsUsdPriceFeeds = [aaveParams.assetsUsdPriceFeeds.staticAWeth, aaveParams.assetsUsdPriceFeeds.staticAUsdc];

  await addAssets(assets, assetsPrecision, assetsUsdPriceFeeds, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
  return aave.address;
}

const deployLido = async (lidoParams, pool, deployConfig) => {
  const lido = await hre.viem.deployContract("LidoAdaptor", [
    lidoParams.lido,
    lidoParams.wETH, // wETH
    lidoParams.stETH, // stETH
    lidoParams.wstETH, // wstETH
    lidoParams.withdrawalQueueERC721,
    pool
  ], deployConfig);
  console.log("LidoAdapter deployed:", lido.address);
  await addAdpatorSupport(pool, lido.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [lidoParams.assets.wstEth];
  const assetsPrecision = [lidoParams.assetsPrecision.wstEth];
  const assetsUsdPriceFeeds = [lidoParams.assetsUsdPriceFeeds.wstEth];

  await addAssets(assets, assetsPrecision, assetsUsdPriceFeeds, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
  return lido.address;
}

const deployCurve = async (curveParams, pool, deployConfig) => {
  const curve = await hre.viem.deployContract("CurveNGAdaptor", [
    pool
  ], deployConfig);
  console.log("CurveNGAdp deployed:", curve.address);
  await addAdpatorSupport(pool, curve.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [curveParams.assets.usdt, curveParams.assets.crvUsd, curveParams.assets.crvUsdUsdtLPToken, curveParams.assets.crvUsdSusdeLPToken];
  const assetsPrecision = [curveParams.assetsPrecision.usdt, curveParams.assetsPrecision.crvUsd, curveParams.assetsPrecision.crvUsdUsdtLPToken, curveParams.assetsPrecision.crvUsdSusdeLPToken];
  const assetsUsdPriceFeeds = [curveParams.assetsUsdPriceFeeds.usdt, curveParams.assetsUsdPriceFeeds.crvUsd, curveParams.assetsUsdPriceFeeds.crvUsdUsdtLPToken, curveParams.assetsUsdPriceFeeds.crvUsdSusdeLPToken];

  await addAssets(assets, assetsPrecision, assetsUsdPriceFeeds, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployEthena = async (ethenaParams, pool, deployConfig) => {
  const ethena = await hre.viem.deployContract("EthenaAdaptor", [
    ethenaParams.ethena,
    ethenaParams.usde,
    pool
  ], deployConfig);
  console.log("Ethena deployed:", ethena.address);
  await addAdpatorSupport(pool, ethena.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [ethenaParams.assets.usde, ethenaParams.assets.sUsde];
  const assetsPrecision = [ethenaParams.assetsPrecision.usde, ethenaParams.assetsPrecision.sUsde];
  const assetsUsdPriceFeeds = [ethenaParams.assetsUsdPriceFeeds.usde, ethenaParams.assetsUsdPriceFeeds.sUsde];
  await addAssets(assets, assetsPrecision, assetsUsdPriceFeeds, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployBeefy = async (beefyParams, pool, deployConfig) => {
  const beefy = await hre.viem.deployContract("BeefyV7Adaptor", [
    pool
  ], deployConfig);
  console.log("Beefy deployed:", beefy.address);
  await addAdpatorSupport(pool, beefy.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [beefyParams.assets.mooCurveCrvUSDsUSDe];
  const assetsPrecision = [beefyParams.assetsPrecision.mooCurveCrvUSDsUSDe];
  const assetsUsdPriceFeeds = [beefyParams.assetsUsdPriceFeeds.mooCurveCrvUSDsUSDe];

  await addAssets(assets, assetsPrecision, assetsUsdPriceFeeds, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployMorpho = async (morphoParams, pool, deployConfig) => {
  const morpho = await hre.viem.deployContract("MorphoVaultAdaptor", [
    pool
  ], deployConfig);
  console.log("Morpho deployed:", morpho.address);
  await addAdpatorSupport(pool, morpho.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [morphoParams.assets.gauntletWETHPrimeVault];
  const assetsPrecision = [morphoParams.assetsPrecision.gauntletWETHPrimeVault];
  const assetsUsdPriceFeeds = [morphoParams.assetsUsdPriceFeeds.gauntletWETHPrimeVault];

  await addAssets(assets, assetsPrecision, assetsUsdPriceFeeds, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
  return morpho.address;
}

const deployOneInch = async (oneInchParams: any, pool: any, deployConfig: any) => {
  const oneInch = await hre.viem.deployContract("OneInchAdaptor", [
    pool,
    oneInchParams.oneInchRouter
  ], deployConfig);
  console.log("OneInch deployed:", oneInch.address);
  await addAdpatorSupport(pool, oneInch.address, true, deployConfig.client.wallet, deployConfig.client.public);
}

const deployRocketPool = async (rocketPoolParams: any, pool: any, deployConfig: any) => {
  const rocketPool = await hre.viem.deployContract("RocketPoolAdaptor", [
    rocketPoolParams.assets.rETH,
    rocketPoolParams.wETH,
    rocketPoolParams.rocketSwapRouter,
    pool
  ], deployConfig);
  console.log("RocketPool deployed:", rocketPool.address);
  await addAdpatorSupport(pool, rocketPool.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [rocketPoolParams.assets.rETH];
  const assetsPrecision = [rocketPoolParams.assetsPrecision.rETH];
  const assetsUsdPriceFeeds = [rocketPoolParams.assetsUsdPriceFeeds.rETH];

  await addAssets(assets, assetsPrecision, assetsUsdPriceFeeds, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

// Deployment-record key -> artifact, for Etherscan verification. Every key the record can carry
// needs an entry: an unmapped key is reported as a failure rather than silently left unverified.
// The Poseidon libraries are circomlibjs bytecode with no Solidity source, so no explorer can
// verify them.
const RECORD_KEY_CONTRACTS: Record<string, string | null> = {
  poolProxy: "PoolProxy",
  poolImpl: "Pool",
  verifier: "Verifier",
  hasher: "Hasher",
  adaptorHandler: "AdaptorHandler",
  gateway: "Gateway",
  paymaster: "Paymaster",
  assetLogic: "AssetLogic",
  babyJubJubLogic: "BabyJubJubLogic",
  merkleTreeLogic: "MerkleTreeLogic",
  queuedMerkleTreeLogic: "QueuedMerkleTreeLogic",
  shieldedAddressLogic: "ShieldedAddressLogic",
  shieldedTransactionLogic: "ShieldedTransactionLogic",
  verifierRegister: "VerifierRegister",
  verifierTreeUpdate: "VerifierTreeUpdate",
  verifierTransact21: "VerifierTransact21",
  verifierTransact22: "VerifierTransact22",
  verifierTransact23: "VerifierTransact23",
  verifierTransact42: "VerifierTransact42",
  verifierTransact44: "VerifierTransact44",
  verifierTransact82: "VerifierTransact82",
  verifierTransact84: "VerifierTransact84",
  // Adaptors (keys from deployAdaptors)
  uniswap: "UniswapV3Adapter",
  aave: "AaveV3Adaptor",
  lido: "LidoAdaptor",
  curve: "CurveNGAdaptor",
  ethena: "EthenaAdaptor",
  beefy: "BeefyV7Adaptor",
  morpho: "MorphoVaultAdaptor",
  oneInch: "OneInchAdaptor",
  rocketPool: "RocketPoolAdaptor",
  poseidonT3: null,
  poseidonT4: null,
  poseidonT5: null,
};

// Verifies every contract in the deployment record on Etherscan, then links PoolProxy to the Pool
// implementation. Constructor arguments come from the creation transactions (see
// script/utils/etherscanVerify.ts), so nothing here has to mirror the deploy calls.
const verifyAll = async (addresses: Record<string, Hex>) => {
  // Library addresses by contract name; each target only uses the libraries its artifact links.
  const byName: Record<string, Hex> = {};
  for (const [key, address] of Object.entries(addresses)) {
    const contract = RECORD_KEY_CONTRACTS[key];
    if (contract && address) byName[contract] = address;
  }

  const targets: VerifyTarget[] = [];
  const results: VerifyResult[] = [];
  for (const [key, address] of Object.entries(addresses)) {
    if (!address) continue;
    const contract = RECORD_KEY_CONTRACTS[key];
    if (contract === null) {
      results.push({ label: key, address, status: "skipped", detail: "raw bytecode, no Solidity source" });
    } else if (contract === undefined) {
      results.push({ label: key, address, status: "failed", detail: "no artifact mapped in RECORD_KEY_CONTRACTS" });
    } else {
      targets.push({ label: key, address, contract, libraries: byName });
    }
  }

  results.push(...(await verifyOnEtherscan(targets)));
  results.push(await linkProxyOnEtherscan(addresses.poolProxy, addresses.poolImpl));
  printVerifySummary(results);
};

// Sequential on purpose: every adaptor registers assets, and the ids they receive come from a
// monotonic counter, so the enabled set and its order here decide the id of every adaptor asset.
// Returns the addresses so the caller can record them without module-level state.
const deployAdaptors = async (pool: any, adpParams: any, deployConfig: any): Promise<Record<string, Hex>> => {
  const { uniswap: uniswapParams, aave: aaveParams, lido: lidoParams, curve: curveParams, ethena: ethenaParams, beefy: beefyParams, morpho: morphoParams, rocketPool: rocketPoolParams, oneInch: oneInchParams } = adpParams;

  return {
    uniswap: await deployUniswap(uniswapParams, pool, deployConfig),
    aave: await deployAave(aaveParams, pool, deployConfig),
    lido: await deployLido(lidoParams, pool, deployConfig),
    // curve: await deployCurve(curveParams, pool, deployConfig),
    // ethena: await deployEthena(ethenaParams, pool, deployConfig),
    // beefy: await deployBeefy(beefyParams, pool, deployConfig),
    morpho: await deployMorpho(morphoParams, pool, deployConfig),
    // oneInch: await deployOneInch(oneInchParams, pool, deployConfig),
    // rocketPool: await deployRocketPool(rocketPoolParams, pool, deployConfig),
  };
}

const addAdpatorSupport = async (pool: any, adpAddress: any, enable: boolean, wallet: any, client: any) => {
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: pool,
      abi: poolAbi,
      functionName: "addAdaptorSupport",
      args: [adpAddress, enable]
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:addAdpSupport", rct.status);
    if (rct.status !== "success") {
      throw new Error(`addAdaptorSupport(${adpAddress}, ${enable}) reverted (tx ${hash})`);
    }
  } catch (error: any) {
    // Fatal: an adaptor the pool does not recognise is dead weight, and continuing would
    // register its assets anyway — shifting the ids of every asset added after it.
    logError("Error supporting adp:", error.message);
    throw error;
  }
}

// Pool.addAssets takes (AssetType, AssetInitParams[]) — zip the parallel config arrays into structs.
const toAssetInitParams = (assets: any, assetsPrecision: any, usdPriceFeeds: any) =>
  assets.map((assetAddress: any, i: number) => ({
    assetAddress,
    precision: assetsPrecision[i],
    usdPriceFeed: usdPriceFeeds[i],
  }));

const addAssets = async (assets: any, assetsPrecision: any, usdPriceFeeds: any, assetType: number, poolAddr: any, wallet: any, client: any) => {
  // Adaptor assets that don't exist on the target chain are configured as the zero address
  // (e.g. Morpho's Gauntlet WETH Prime vault is mainnet-only). Pool.addAssets reverts with
  // ZeroAddress() on those, and the call is all-or-nothing — sending them anyway would drop
  // the assets that *are* configured in the same batch.
  const keep = assets.map((a: any) => !isUnconfigured(a));
  const toAdd = assets.filter((_: any, i: number) => keep[i]);
  const skippedCount = assets.length - toAdd.length;

  if (skippedCount > 0) {
    console.warn(`⚠️  Skipping ${skippedCount} asset(s) not configured on this chain (zero address)`);
  }
  if (toAdd.length === 0) {
    console.log("No configured assets to add, skipping addAssets");
    return;
  }

  console.log("Adding assets:", toAdd);
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolAddr,
      abi: poolAbi,
      functionName: "addAssets",
      args: [assetType, toAssetInitParams(
        toAdd,
        assetsPrecision.filter((_: any, i: number) => keep[i]),
        usdPriceFeeds.filter((_: any, i: number) => keep[i])
      )],
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:addAsset", rct.status);
    if (rct.status !== "success") {
      throw new Error(`addAssets reverted for ${toAdd.join(", ")} (tx ${hash})`);
    }
  } catch (e) {
    // Fatal: addAssets is the only thing that advances the pool's asset counter, so a
    // silently dropped batch shifts the id of every asset registered afterwards.
    logError("Error adding assets:", e);
    throw e;
  }
}

const addAssetsAndRevokers = async (poolProxy: any, chainParams: any, commonParams: any, client: any, wallet: any) => {
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolProxy,
      abi: poolAbi,
      functionName: "addAssets",
      args: [
        chainParams.initAssetType,
        toAssetInitParams(
          chainParams.initAssetAddresses,
          chainParams.initAssetsPrecision,
          chainParams.initAssetToUSDChainlinkFeeds
        ),
      ],
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:addAsset", rct.status);
    if (rct.status !== "success") {
      throw new Error(`addAssets reverted for the base assets (tx ${hash})`);
    }

    for (let i = 0; i < commonParams.revokers.length; i++) {
      const revokerPublicKey = commonParams.revokers[i].revokerPublicKey;
      const encryptionPublicKey = commonParams.revokers[i].encryptionPublicKey;
      const revokerName = commonParams.revokers[i].name;
      // Validated by assertRevokerMetadata before any of this ran — see that function for why a
      // wrong CID here would be permanent.
      const metadata = encodeRevokerMetadata(commonParams.revokers[i].pinataCID);

      //@ts-ignore
      const hash = await wallet.writeContract({
        address: poolProxy,
        abi: poolAbi,
        functionName: "registerRevoker",
        args: [revokerPublicKey, encryptionPublicKey, metadata],
      });

      const rct = await client.waitForTransactionReceipt({ hash });
      console.log("rct:revokerAdd", rct.status);
      if (rct.status !== "success") {
        throw new Error(`registerRevoker reverted for "${revokerName}" (tx ${hash})`);
      }
    }
  } catch (error: any) {
    // Fatal: the base assets fix the id of every adaptor asset registered afterwards, and
    // the revokers are registered in the same block of work. A pool that comes out of this
    // half-configured cannot be repaired in place — it needs a proxy redeploy.
    logError("Error adding assets and revokers:", error.message);
    throw error;
  }
}

// Pool.getAsset is overloaded (uint24 / address); pin the uint24 overload so viem does not
// have to infer which one to encode.
// A floor for the deployer balance, not an estimate of the deploy cost: this run deploys five
// libraries, an implementation, a proxy, nine verifiers and four adaptors, then makes a dozen
// owner-gated calls. Gas prices vary too much to predict, so this only catches the unfunded case.
const MIN_DEPLOYER_BALANCE_WEI = parseEther("0.15");

const getAssetByIdAbi = poolAbi.filter(
  (item: any) => item.name === "getAsset" && item.inputs?.[0]?.type === "uint24"
);

type OnChainAsset = { id: number; assetAddress: Hex; isActive: boolean };

// Unknown ids read back as the empty Asset struct (isActive: false, assetAddress: 0x0)
// rather than reverting, so this is safe to call for an id that was never assigned.
const getAssetById = async (poolAddr: Hex, assetId: number, client: any): Promise<OnChainAsset> =>
  (await client.readContract({
    address: poolAddr,
    abi: getAssetByIdAbi,
    functionName: "getAsset",
    args: [assetId],
  })) as OnChainAsset;

/**
 * Confirms on-chain that `GAS_ASSET_ID` resolves to the wrapped native token. Must run after the
 * base assets are registered and before `deployAdaptors`.
 *
 * Not a re-run of `assertChainAssetConfig`: that checks the config's id arithmetic in TypeScript,
 * against a copy of `AssetLogic.addAsset`'s formula. This reads the deployed pool, so it is the
 * only check that catches the Solidity side drifting from what this script and `Paymaster` assume —
 * a changed id derivation, or a counter that no longer starts at 1 because `initialize` registered
 * something. One read, on the one id everything else is anchored to.
 */
const assertGasAssetRegistered = async (poolAddr: Hex, chainParams: any, client: any) => {
  // Unset nativeWToken disables native ETH deposits (Pool.setNativeWToken) — supported, so warn.
  const wNativeToken: Hex = chainParams.nativeWToken;
  if (isUnconfigured(wNativeToken)) {
    console.warn("⚠️  nativeWToken is unset — native ETH deposits are disabled on this pool");
    return;
  }

  // Paymaster reads GAS_ASSET_ID's `precision` as the exponent in convertFeeFromGasTokenToFeeAsset
  // and returns `maxCostEth` verbatim when the fee asset *is* GAS_ASSET_ID, so pointing that id at
  // a 6-decimal token puts every gas fee off by 10**12. Passing also proves Pool can resolve
  // `_assetIds[nativeWToken]` for the native-ETH wrap path.
  const gasAsset = await getAssetById(poolAddr, GAS_ASSET_ID, client);
  if (!gasAsset.isActive || !isAddressEqual(gasAsset.assetAddress, wNativeToken)) {
    throw new Error(
      `Asset ${GAS_ASSET_ID} is ${gasAsset.assetAddress} (active: ${gasAsset.isActive}), not the configured ` +
      `nativeWToken ${wNativeToken}. Paymaster.GAS_ASSET_ID hardcodes ${GAS_ASSET_ID} as this chain's gas ` +
      `token, so gas fees would be converted against the wrong token's precision.`
    );
  }
  console.log(`✅ asset ${GAS_ASSET_ID} = ${gasAsset.assetAddress} (nativeWToken)`);
}

/**
 * The record for this run: `deployments/<DEPLOYMENT_NAME>-<date>.json` (name defaults to the
 * network's), with DEPLOYMENT_PURPOSE as its first key. A dry run against the mainnet fork shares
 * mainnet's chain id, so its file carries a `-dry-run` suffix and `dryRun` is in the payload: a
 * file that reads as the canonical mainnet registry must not contain anvil addresses.
 */
const deploymentRecordTarget = (dryRun: boolean): RecordTarget => ({
  name: process.env.DEPLOYMENT_NAME ?? hre.network.name,
  purpose: process.env.DEPLOYMENT_PURPOSE ?? "",
  suffix: dryRun ? "-dry-run" : "",
});

const writeDeploymentRecord = (chainId: number, dryRun: boolean, addresses: Record<string, Hex>) => {
  const path = writeRecord(deploymentRecordTarget(dryRun), {
    network: hre.network.name, chainId, dryRun, deployedAt: new Date().toISOString(), addresses,
  });
  console.log("Deployment record written to:", path);
};

const main = async () => {
  const chain = await getChainForCurrentNetwork(hre);
  console.log("Deploying to chain:", chain);

  // A network whose name says "fork" carries a real chain id (and, on mainnet, will carry the real
  // deployer key) while being meant for dry-runs only. Fail closed if the node on the other end is
  // not a local development chain — this is the check standing between a typo'd RPC URL and a live
  // mainnet deployment.
  const dryRun = await isDevelopmentNode(hre);
  if (/fork/i.test(hre.network.name) && !dryRun) {
    throw new Error(
      `Network "${hre.network.name}" is a dry-run network, but the node behind it is not anvil or ` +
      `Hardhat. Refusing to deploy — nothing has been deployed. Start the fork first ` +
      `(npm run fork:mainnet) or deploy against a real network explicitly.`
    );
  }
  if (dryRun) {
    console.log(`Dry run: ${hre.network.name} is a local development node`);
  }
  // The record is written after everything is deployed; a missing purpose or an existing record
  // must fail here, while nothing has been spent.
  assertRecordWritable(deploymentRecordTarget(dryRun));

  const client = await hre.viem.getPublicClient({ chain });

  const chainId = await client.getChainId();

  // hardhat.config.ts declares a chain id and the node reports one. getChainForCurrentNetwork
  // builds the viem Chain from the declared value, while every config lookup below keys off the
  // reported one, so an RPC URL pointing somewhere other than the network it is configured as
  // makes those diverge silently: transactions would be signed for one chain while the pool is
  // configured from another chain's entry in config.json.
  const declaredChainId = hre.network.config.chainId;
  if (declaredChainId !== undefined && declaredChainId !== chainId) {
    throw new Error(
      `Network "${hre.network.name}" declares chainId ${declaredChainId} in hardhat.config.ts, but the ` +
      `node reports ${chainId}. The RPC URL is pointing at a different chain — nothing has been deployed.`
    );
  }

  const wallets = await hre.viem.getWalletClients({ chain });

  const deployConfig: DeployContractConfig = {
    client: {
      public: client,
      wallet: wallets[0]
    } as KeyedClient
  }

  const commonParams = config.common as CommonParams;
  const adpParams = config.adpConfig[chainId] as AdaptorParams;
  const chainParams = config[chainId] as ChainParams;

  // Everything below this line costs gas, so validate the config first. Both lookups above are
  // plain index reads that yield undefined for an unconfigured chain — deployAdaptors would only
  // notice once the core contracts were already on-chain.
  if (!chainParams) {
    throw new Error(`config.json has no entry for chain ${chainId} — nothing has been deployed`);
  }
  assertChainAssetConfig(chainId, chainParams);
  // Pins the verifier sources to a ceremony. Only delta distinguishes one phase-2 from another,
  // so a stale verifier is invisible to arity checks and surfaces after deployment as
  // InvalidTransactionProof.
  assertVerifiersMatchCeremony();
  // Pins each revoker's pinataCID to a document committed in docs/. Registration happens in the
  // same try block as the base assets, so a CID problem discovered there leaves a pool that has
  // assets but no revoker — unusable and unrepairable. The gateway check that follows is advisory.
  assertRevokerMetadata(commonParams.revokers);
  await checkRevokerMetadataIsPinned(commonParams.revokers);
  if (!adpParams) {
    throw new Error(`adaptorConfig.json has no entry for chain ${chainId} — nothing has been deployed`);
  }

  // A zero or unset hardwareWalletOwner is the documented way to retain deployer ownership for
  // local testing: transferOwnershipToOwner skips every handover and reports "skipped", and
  // assertOwnershipTransferred only fails on "failed". So on a real network that combination
  // completes as a successful deployment while leaving the deployer EOA owning Pool, Verifier,
  // AdaptorHandler, Gateway and Paymaster — including upgradeToAndCall on the UUPS proxy, which
  // is unrestricted control of user funds by whatever key happened to run this script.
  if (!dryRun) {
    const deployer = wallets[0].account.address as Hex;
    const owner = commonParams.hardwareWalletOwner;
    if (isUnconfigured(owner)) {
      throw new Error(
        `common.hardwareWalletOwner is unset for a deployment to chain ${chainId}. Ownership would ` +
        `stay with the deployer ${deployer} and the run would still report success — nothing has ` +
        `been deployed. Set it to the hardware wallet or multisig, or use a dry-run network.`
      );
    }
    if (isAddressEqual(owner, deployer)) {
      throw new Error(
        `common.hardwareWalletOwner (${owner}) is the deployer for chain ${chainId}, so the ` +
        `protocol would be owned by the deploying key — nothing has been deployed.`
      );
    }
    console.log(`Ownership will transfer to ${owner} (deployer ${deployer})`);

    // Running dry midway is not a retryable failure here: addAssets is the only thing that
    // advances the pool's asset counter, so a partial run shifts the id of every asset added
    // afterwards and the pool has to be redeployed. This is a floor, not an estimate — it only
    // catches an unfunded or nearly-empty deployer, which is the common case.
    const balance = await client.getBalance({ address: deployer });
    console.log(`Deployer balance: ${formatEther(balance)} ETH`);
    if (balance === BigInt(0)) {
      throw new Error(
        `Deployer ${deployer} has no balance on chain ${chainId} — nothing has been deployed.`
      );
    }
    if (balance < MIN_DEPLOYER_BALANCE_WEI) {
      console.warn(
        `⚠️  Deployer balance is ${formatEther(balance)} ETH, below the ${formatEther(MIN_DEPLOYER_BALANCE_WEI)} ETH ` +
        `floor. A run that stops midway leaves a pool that cannot be repaired in place.`
      );
    }
  }

  // Add assets
  // addAssets([`0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8` as `0x${string}`], [18], 1, `0x62e7485535ea31382dcc3bbfc399ddd6b9c9b27f` as `0x${string}`, wallets[0], client);

  // individual adp deployment
  // deployMorpho(adpParams.morpho, "0x9163043b553aDeF9fE44b088922560cfBFdEC51b" as Hex, deployConfig);

  const asset = await hre.viem.deployContract("AssetLogic", [], deployConfig);
  console.log("AssetLogic deployed:", asset.address);

  const merkleTree = await hre.viem.deployContract("MerkleTreeLogic", [], deployConfig);
  console.log("MerkleTreeLogic deployed:", merkleTree.address);

  const queuedMerkleTree = await hre.viem.deployContract(
    "QueuedMerkleTreeLogic", [], deployConfig
  );
  console.log("QueuedMerkleTreeLogic deployed:", queuedMerkleTree.address);

  const shieldedAddress = await hre.viem.deployContract(
    "ShieldedAddressLogic",
    [],
    {
      client: deployConfig.client,
      libraries: {
        MerkleTreeLogic: merkleTree.address,
      },
    },
  );
  console.log("ShieldedAddressLogic deployed:", shieldedAddress.address);

  const shieldedTransaction = await hre.viem.deployContract(
    "ShieldedTransactionLogic",
    [],
    {
      client: deployConfig.client,
      libraries: {
        AssetLogic: asset.address,
        MerkleTreeLogic: merkleTree.address,
        QueuedMerkleTreeLogic: queuedMerkleTree.address,
      },
    }
  );
  console.log("ShieldedTransactionLogic deployed:", shieldedTransaction.address);

  // External library Pool calls for the revoker-key subgroup check (registerRevoker).
  const babyJubJub = await hre.viem.deployContract("BabyJubJubLogic", [], deployConfig);
  console.log("BabyJubJubLogic deployed:", babyJubJub.address);

  const adaptorHandler = await hre.viem.deployContract("AdaptorHandler", [], deployConfig);
  console.log("AdaptorHandler deployed: ", adaptorHandler.address);

  const poolImpl = await hre.viem.deployContract("Pool", [], {
    client: deployConfig.client,
    libraries: {
      AssetLogic: asset.address,
      MerkleTreeLogic: merkleTree.address,
      QueuedMerkleTreeLogic: queuedMerkleTree.address,
      ShieldedAddressLogic: shieldedAddress.address,
      ShieldedTransactionLogic: shieldedTransaction.address,
      BabyJubJubLogic: babyJubJub.address,
    },
  });
  console.log("Pool deployed:", poolImpl.address);

  const { hasher, poseidonT3, poseidonT4, poseidonT5 } = await deployHasher(
    deployConfig.client.wallet,
    client,
    deployConfig
  );
  console.log("Hasher deployed:", hasher);

  // Ownership is handed over below with the rest of the Ownable contracts; this only sets
  // the verifier manager.
  const { verifier, ...verifiers } = await deployVerifier(
    deployConfig,
    commonParams.hardwareWalletOwner
  );

  const initAddressParams = {
    verifier: verifier,
    adaptorHandler: adaptorHandler.address,
    screener: chainParams.sanctionsList,
    hasher: hasher,
    pauser: commonParams.pauserAddress, // zeroAddress leaves pausing exclusive to the owner
  }

  const ONE_HOUR = 3600n;
  const configParams = {
    withdrawFeeBps: BigInt(commonParams.withdrawFeeBps),
    tvlLimitUsd: BigInt(5_000e6),    // $5,000 (6-decimal precision)
    minDepositUsd: BigInt(10e6),      // $10 (6-decimal precision)
    maxDepositUsd: BigInt(250e6),    // $250 (6-decimal precision)
    priceFeedStalenessThreshold: ONE_HOUR * 30n, // 30 hours in seconds
    nativeWToken: chainParams.nativeWToken,      // wrapped native token (e.g. WETH) for native ETH deposits
  };

  const args = [
    commonParams.commitmentTreeQueueSize,
    initAddressParams,
    configParams,
  ];

  const initData = encodeFunctionData({
    abi: poolAbi,
    functionName: "initialize",
    args: args as any,
  });

  const poolProxy = await hre.viem.deployContract("PoolProxy", [
    poolImpl.address,
    initData,
  ], deployConfig);
  console.log("PoolProxy deployed:", poolProxy.address);

  // Set protocol version
  // @ts-ignore
  const setVersionHash = await wallets[0].writeContract({
    address: poolProxy.address,
    abi: poolAbi,
    functionName: "setVersion",
    args: [commonParams.protocolVersion],
  });
  await client.waitForTransactionReceipt({ hash: setVersionHash });
  console.log("Pool: version set to", commonParams.protocolVersion);

  // nativeWToken is set via PoolConfigParams during initialize() above; no separate
  // setWToken call is needed for fresh deployments.

  // Pause before any of the setup below runs: only the user-facing entry points are
  // whenNotPaused (transact, register), so every owner-gated setup call still works while
  // paused — and a setup step that aborts the run leaves the pool closed rather than live
  // and half-configured.
  // @ts-ignore
  const pauseHash = await wallets[0].writeContract({
    address: poolProxy.address,
    abi: poolAbi,
    functionName: "pause",
  });
  await client.waitForTransactionReceipt({ hash: pauseHash });
  console.log("Pool: paused");

  // @ts-ignore
  const setPoolTxHash = await wallets[0].writeContract({
    address: adaptorHandler.address,
    abi: adaptorHandlerAbi,
    functionName: "setVeilnyxPool",
    args: [poolProxy.address],
  });
  await client.waitForTransactionReceipt({ hash: setPoolTxHash });
  console.log("AdaptorHandler: veilnyxPool set to", poolProxy.address);

  // ERC4337 infra setup
  const { gateway, paymaster } = await deployErc4337Infra(chainParams, poolProxy.address, deployConfig);

  // Asset & Revoker Setup
  await addAssetsAndRevokers(poolProxy.address, chainParams, commonParams, client, deployConfig.client.wallet);

  // Adaptor asset ids continue the same counter as the base assets, so confirm the anchor id the
  // Paymaster and SDK are written against before anything is deployed on top of it.
  await assertGasAssetRegistered(poolProxy.address, chainParams, client);

  // Deploy Adaptors (should be after base assets are added to maintain the expected ID order)
  const adaptors = await deployAdaptors(poolProxy.address, adpParams, deployConfig);

  // Hand every Ownable contract over to the hardware wallet / multisig. Must stay after all
  // owner-gated setup above (setVersion, setVeilnyxPool, addAssets, registerRevoker,
  // addAdaptorSupport, setChainlinkFeed, pause) — those revert once the deployer is no longer
  // the owner. Set common.hardwareWalletOwner to zeroAddress to retain deployer ownership for
  // testing.
  const ownershipResults = await transferOwnershipToOwner(
    [
      { contract: "Pool", address: poolProxy.address, label: "PoolProxy" },
      { contract: "Verifier", address: verifier },
      { contract: "AdaptorHandler", address: adaptorHandler.address },
      { contract: "Gateway", address: gateway },
      { contract: "Paymaster", address: paymaster },
    ],
    commonParams.hardwareWalletOwner,
    deployConfig
  );

  // Record every deployed address before verification, so an aborted verify still leaves the
  // addresses on disk — on a real deploy they are not recoverable from anywhere else.
  const deployedAddresses: Record<string, Hex> = {
    poolProxy: poolProxy.address,
    poolImpl: poolImpl.address,
    verifier,
    hasher,
    adaptorHandler: adaptorHandler.address,
    gateway,
    paymaster,
    assetLogic: asset.address,
    merkleTreeLogic: merkleTree.address,
    queuedMerkleTreeLogic: queuedMerkleTree.address,
    shieldedAddressLogic: shieldedAddress.address,
    shieldedTransactionLogic: shieldedTransaction.address,
    babyJubJubLogic: babyJubJub.address,
    poseidonT3,
    poseidonT4,
    poseidonT5,
    // The sub-verifiers and Poseidon libraries above are deployed standalone rather than through
    // hre.viem's artifact registry, so nothing else on disk holds their addresses.
    ...verifiers,
    ...adaptors,
  };
  writeDeploymentRecord(chainId, dryRun, deployedAddresses);

  if (dryRun) {
    console.log("Dry run: skipping Etherscan verification");
  } else {
    await verifyAll(deployedAddresses);
  }

  // Fail the run (after verification, so it still happens) if anything is still deployer-owned
  assertOwnershipTransferred(ownershipResults);
};

// `hardhat run` does not fail on an unhandled rejection alone — set the exit code explicitly
// so an aborted deploy is visible to CI and to `pnpm deployCoreWithAdp:*`.
main().catch((error) => {
  logError(error);
  process.exitCode = 1;
});
