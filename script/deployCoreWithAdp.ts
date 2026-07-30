import hre from "hardhat";
import {
  encodeAbiParameters,
  encodeFunctionData,
  parseAbiParameters,
  isAddressEqual,
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
import { assertOwnershipTransferred, transferOwnershipToOwner } from "./utils/ownership";
import { deployErc4337Infra } from "./erc4337Infra";
import { mkdirSync, writeFileSync } from "fs";
import { join } from "path";

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

// Resolves the Etherscan API endpoint for the network the script is running against,
// reusing the `etherscan.customChains` entry from hardhat.config.ts so the URL lives in
// one place. Falls back to the Etherscan V2 unified endpoint for the current chain id.
const getEtherscanApiUrl = (): string => {
  const networkName = hre.network.name;
  const chainId = hre.network.config.chainId;
  const customChains = (hre.config as any).etherscan?.customChains ?? [];

  const match = customChains.find(
    (c: any) => c.network === networkName || c.chainId === chainId
  );

  if (match?.urls?.apiURL) return match.urls.apiURL;

  console.warn(
    `getEtherscanApiUrl: no customChains entry for ${networkName} (chainId: ${chainId}), falling back to the Etherscan V2 endpoint`
  );
  return `https://api.etherscan.io/v2/api?chainid=${chainId}`;
};

const verifyProxy = async (proxyAddress: string, implAddress: string) => {
  const apiKey = process.env.ETHERSCAN_API_KEY;
  if (!apiKey) {
    logError("verifyProxy: ETHERSCAN_API_KEY not set, skipping proxy link");
    return;
  }

  const baseUrl = getEtherscanApiUrl();
  console.log("verifyProxy: using Etherscan API:", baseUrl);

  // Step 1: submit proxy verification
  const submitBody = new URLSearchParams({
    module: "contract",
    action: "verifyproxycontract",
    apikey: apiKey,
    address: proxyAddress,
    expectedimplementation: implAddress,
  });
  const submitRes = await fetch(baseUrl, {
    method: "POST",
    body: submitBody,
  });
  const submitJson = await submitRes.json() as any;

  if (submitJson.status !== "1") {
    logError("verifyProxy: proxy verification submission failed:", submitJson.result);
    return;
  }

  const guid = submitJson.result;
  console.log("verifyProxy: submitted, guid:", guid);

  // Step 2: poll for result
  for (let i = 0; i < 12; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const checkBody = new URLSearchParams({
      module: "contract",
      action: "checkproxyverification",
      apikey: apiKey,
      guid,
    });
    const checkRes = await fetch(baseUrl, { method: "POST", body: checkBody });
    const checkJson = await checkRes.json() as any;

    if (checkJson.result === "Pending in queue") {
      console.log("verifyProxy: still pending...");
      continue;
    }
    if (checkJson.status === "1" || checkJson.result?.toLowerCase().includes("already verified")) {
      console.log("verifyProxy: proxy linked to implementation:", implAddress);
      return;
    }
    logError("verifyProxy: failed:", checkJson.result);
    return;
  }

  logError("verifyProxy: timed out waiting for result");
};

const verifyAll = async (contracts: {
  asset: any;
  merkleTree: any;
  queuedMerkleTree: any;
  shieldedAddress: any;
  shieldedTransaction: any;
  adaptorHandler: any;
  poolImpl: any;
  poolProxy: any;
  initData: `0x${string}`;
}) => {
  const { asset, merkleTree, queuedMerkleTree, shieldedAddress, shieldedTransaction, adaptorHandler, poolImpl, poolProxy, initData } = contracts;

  const verifications = [
    { address: asset.address, constructorArguments: [] },
    { address: merkleTree.address, constructorArguments: [] },
    { address: queuedMerkleTree.address, constructorArguments: [] },
    {
      address: shieldedAddress.address,
      constructorArguments: [],
      libraries: { MerkleTreeLogic: merkleTree.address },
    },
    {
      address: shieldedTransaction.address,
      constructorArguments: [],
      libraries: {
        AssetLogic: asset.address,
        MerkleTreeLogic: merkleTree.address,
        QueuedMerkleTreeLogic: queuedMerkleTree.address,
      },
    },
    { address: adaptorHandler.address, constructorArguments: [] },
    {
      address: poolImpl.address,
      constructorArguments: [],
      libraries: {
        AssetLogic: asset.address,
        MerkleTreeLogic: merkleTree.address,
        QueuedMerkleTreeLogic: queuedMerkleTree.address,
        ShieldedAddressLogic: shieldedAddress.address,
        ShieldedTransactionLogic: shieldedTransaction.address,
      },
    },
  ];

  for (const v of verifications) {
    try {
      await hre.run("verify:verify", v);
      console.log("Verified:", v.address);
    } catch (e: any) {
      if (e.message?.includes("Already Verified") || e.message?.includes("already verified")) {
        console.log("Already verified:", v.address);
      } else {
        logError("Verification failed for", v.address, e.message);
      }
    }
  }

  // PoolProxy verification is split into two explicit steps because hardhat-verify
  // has a bug when used with customChains URLs that already contain "?" — it tries
  // to append query params and blows up before the proxy-link request is made.
  //
  // Step 1: Source submission via hre.run("verify:verify")
  //   - Submits the PoolProxy Solidity source + compiler settings to Etherscan.
  //   - Source IS submitted successfully before the URL bug triggers on the poll step.
  //   - We tolerate the "Query params cannot be passed" error and move on.
  //
  // Step 2: Proxy-to-implementation linking via direct Etherscan V2 API (verifyProxy)
  //   - Calls `verifyproxycontract` + `checkproxyverification` directly with fetch,
  //     bypassing hardhat-verify entirely to avoid the URL construction bug.
  //   - This registers PoolProxy as a proxy pointing to the Pool implementation.

  // Step 1: submit source code
  try {
    await hre.run("verify:verify", {
      address: poolProxy.address,
      constructorArguments: [poolImpl.address, initData],
    });
    console.log("Verified (source):", poolProxy.address);
  } catch (e: any) {
    if (e.message?.includes("Already Verified") || e.message?.includes("already verified")) {
      console.log("Already verified (source):", poolProxy.address);
    } else if (e.message?.includes("Query params cannot be passed")) {
      console.log("verifyAll: proxy source submit hit URL bug — source may still have been submitted. Proceeding to proxy link step.");
    } else {
      logError("Verification failed for", poolProxy.address, e.message);
    }
  }

  // Step 2: link proxy to implementation via direct Etherscan V2 API
  await verifyProxy(poolProxy.address, poolImpl.address);
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
      const revokerDescription = commonParams.revokers[i].description;
      const metadata = encodeAbiParameters(
        parseAbiParameters("string name, string description"),
        [revokerName, revokerDescription]
      );

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
 * Writes every deployed address to `deployments/`, keyed by network name rather than chain id: a
 * dry run against the mainnet fork shares mainnet's chain id, and a file that reads as the
 * canonical mainnet registry must not contain anvil addresses. `dryRun` is recorded in the payload
 * for the same reason.
 */
const writeDeploymentRecord = (chainId: number, dryRun: boolean, addresses: Record<string, Hex>) => {
  const dir = join(__dirname, "..", "deployments");
  mkdirSync(dir, { recursive: true });
  const path = join(dir, `${hre.network.name}-${chainId}.json`);
  const record = { network: hre.network.name, chainId, dryRun, deployedAt: new Date().toISOString(), addresses };
  writeFileSync(path, JSON.stringify(record, null, 2));
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
  if (!adpParams) {
    throw new Error(`adaptorConfig.json has no entry for chain ${chainId} — nothing has been deployed`);
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
    },
  });
  console.log("Pool deployed:", poolImpl.address);

  const { hasher } = await deployHasher(deployConfig.client.wallet, client, deployConfig);
  console.log("Hasher deployed:", hasher);

  // Ownership is handed over below with the rest of the Ownable contracts; this only sets
  // the verifier manager.
  const verifier = await deployVerifier(deployConfig, commonParams.hardwareWalletOwner);

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
  writeDeploymentRecord(chainId, dryRun, {
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
    ...adaptors,
  });

  if (dryRun) {
    console.log("Dry run: skipping Etherscan verification");
  } else {
    await verifyAll({ asset, merkleTree, queuedMerkleTree, shieldedAddress, shieldedTransaction, adaptorHandler, poolImpl, poolProxy, initData });
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
