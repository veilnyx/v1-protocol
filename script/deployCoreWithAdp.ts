import hre from "hardhat";
import {
  encodeAbiParameters,
  encodeFunctionData,
  parseAbiParameters,
  defineChain,
  parseEther,
  toFunctionSelector,
  http,
  createWalletClient,
  Chain,
  zeroAddress
} from "viem";

import { DeployContractConfig, KeyedClient } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams, AdaptorParams, CommonParams, getHex } from "./configs";
import { deployHasher } from "./hasher";
import { deployVerifier } from "./verifier";
import { getChainForCurrentNetwork } from "./utils/chainUtils";
import { assertOwnershipTransferred, transferOwnershipToOwner } from "./utils/ownership";
import { deployErc4337Infra } from "./erc4337Infra";

const config = loadConfigs();

// ABIs
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const adaptorHandlerAbi = hre.artifacts.readArtifactSync("AdaptorHandler").abi;

const deployUniswap = async (uniswapParams, pool, deployConfig) => {
  const uniswap = await hre.viem.deployContract("UniswapV3Adapter", [
    uniswapParams.uniswapSwapRouter02,
    pool
  ], deployConfig)
  console.log("UniswapV3Adapter deployed:", uniswap.address);
  await addAdpatorSupport(pool, uniswap.address, true, deployConfig.client.wallet, deployConfig.client.public);
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
    console.error("verifyProxy: ETHERSCAN_API_KEY not set, skipping proxy link");
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
    console.error("verifyProxy: proxy verification submission failed:", submitJson.result);
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
    console.error("verifyProxy: failed:", checkJson.result);
    return;
  }

  console.error("verifyProxy: timed out waiting for result");
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
        console.error("Verification failed for", v.address, e.message);
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
      console.error("Verification failed for", poolProxy.address, e.message);
    }
  }

  // Step 2: link proxy to implementation via direct Etherscan V2 API
  await verifyProxy(poolProxy.address, poolImpl.address);
};

const deployAdaptors = async (pool: any, adpParams: any, deployConfig: any) => {
  const { uniswap: uniswapParams, aave: aaveParams, lido: lidoParams, curve: curveParams, ethena: ethenaParams, beefy: beefyParams, morpho: morphoParams, rocketPool: rocketPoolParams, oneInch: oneInchParams } = adpParams;

  await deployUniswap(uniswapParams, pool, deployConfig);
  await deployAave(aaveParams, pool, deployConfig);
  await deployLido(lidoParams, pool, deployConfig);
  // await deployCurve(curveParams, pool, deployConfig);
  // await deployEthena(ethenaParams, pool, deployConfig);
  // await deployBeefy(beefyParams, pool, deployConfig);
  await deployMorpho(morphoParams, pool, deployConfig);
  // await deployOneInch(oneInchParams, pool, deployConfig);
  // await deployRocketPool(rocketPoolParams, pool, deployConfig);
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
  } catch (error) {
    console.log("Error supporting adp");
    console.log(error.message);
  }
}

const addAssets = async (assets: any, assetsPrecision: any, usdPriceFeeds: any, assetType: number, poolAddr: any, wallet: any, client: any) => {
  console.log("Adding assets:", assets);
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolAddr,
      abi: poolAbi,
      functionName: "addAssets",
      args: [assetType, assets, assetsPrecision, usdPriceFeeds],
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:addAsset", rct.status);
  } catch (e) {
    console.log("Error adding assets:", e);
  }
}

const addAssetsAndRevokers = async (poolProxy: any, chainParams: any, commonParams: any, client: any, wallet: any) => {
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolProxy,
      abi: poolAbi,
      functionName: "addAssets",
      args: [chainParams.initAssetType, chainParams.initAssetAddresses, chainParams.initAssetsPrecision, chainParams.initAssetToUSDChainlinkFeeds],
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:addAsset", rct.status);

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
    }
  } catch (error) {
    console.log(error.message);
  }
}

const main = async () => {
  const chain = await getChainForCurrentNetwork(hre);
  console.log("Deploying to chain:", chain);

  const client = await hre.viem.getPublicClient({ chain });

  const chainId = await client.getChainId();
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

  const verifier = await deployVerifier(
    deployConfig,
    commonParams.hardwareWalletOwner,
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
    minDepositUsd: BigInt(2e6),      // $2 (6-decimal precision)
    maxDepositUsd: BigInt(200e6),    // $200 (6-decimal precision)
    priceFeedStalenessThreshold: ONE_HOUR * 2n, // 2 hours in seconds
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

  // Deploy Adaptors (should be after base assets are added to maintain the expected ID order)
  await deployAdaptors(poolProxy.address, adpParams, deployConfig);

  // pause the protocol immediately after deployment to prevent any interactions before the setup is complete
  // @ts-ignore
  const pauseHash = await wallets[0].writeContract({
    address: poolProxy.address,
    abi: poolAbi,
    functionName: "pause",
  });
  await client.waitForTransactionReceipt({ hash: pauseHash });
  console.log("Pool: paused");

  // Hand every Ownable contract over to the hardware wallet / multisig. Must stay after all
  // owner-gated setup above (setVersion, setVeilnyxPool, addAssets, registerRevoker,
  // addAdaptorSupport, setChainlinkFeed, pause) — those revert once the deployer is no longer
  // the owner. Set common.hardwareWalletOwner to zeroAddress to retain deployer ownership for
  // testing. Verifier is listed for completeness; deployVerifier already transfers it, so it is
  // reported as `already-owned`.
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

  // Verify all core contracts on Etherscan
  await verifyAll({ asset, merkleTree, queuedMerkleTree, shieldedAddress, shieldedTransaction, adaptorHandler, poolImpl, poolProxy, initData });

  // Fail the run (after verification, so it still happens) if anything is still deployer-owned
  assertOwnershipTransferred(ownershipResults);
};

main().catch(console.error);
