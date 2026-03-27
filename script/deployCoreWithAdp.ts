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
import { loadConfigs, ChainParams, AdaptorParams, CommonParams } from "./configs";
import { deployHasher } from "./hasher";
import { deployVerifier } from "./verifier";
import { getChainForCurrentNetwork } from "./utils/chainUtils";
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

  await addAssets(assets, assetsPrecision, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
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

  await addAssets(assets, assetsPrecision, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployCurve = async (curveParams, pool, deployConfig) => {
  const curve = await hre.viem.deployContract("CurveNGAdaptor", [
    pool
  ], deployConfig);
  console.log("CurveNGAdp deployed:", curve.address);
  await addAdpatorSupport(pool, curve.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [curveParams.assets.usdt, curveParams.assets.crvUsd, curveParams.assets.crvUsdUsdtLPToken, curveParams.assets.crvUsdSusdeLPToken];
  const assetsPrecision = [curveParams.assetsPrecision.usdt, curveParams.assetsPrecision.crvUsd, curveParams.assetsPrecision.crvUsdUsdtLPToken, curveParams.assetsPrecision.crvUsdSusdeLPToken];

  await addAssets(assets, assetsPrecision, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
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
  await addAssets(assets, assetsPrecision, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployBeefy = async (beefyParams, pool, deployConfig) => {
  const beefy = await hre.viem.deployContract("BeefyV7Adaptor", [
    pool
  ], deployConfig);
  console.log("Beefy deployed:", beefy.address);
  await addAdpatorSupport(pool, beefy.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [beefyParams.assets.mooCurveCrvUSDsUSDe];
  const assetsPrecision = [beefyParams.assetsPrecision.mooCurveCrvUSDsUSDe];

  await addAssets(assets, assetsPrecision, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployMorpho = async (morphoParams, pool, deployConfig) => {
  const morpho = await hre.viem.deployContract("MorphoVaultAdaptor", [
    pool
  ], deployConfig);
  console.log("Morpho deployed:", morpho.address);
  await addAdpatorSupport(pool, morpho.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [morphoParams.assets.gauntletWETHPrimeVault];
  const assetsPrecision = [morphoParams.assetsPrecision.gauntletWETHPrimeVault];

  await addAssets(assets, assetsPrecision, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployOneInch = async (pool, deployConfig) => {
  const oneInch = await hre.viem.deployContract("OneInchAdaptor", [
    pool
  ], deployConfig);
  console.log("OneInch deployed:", oneInch.address);
  await addAdpatorSupport(pool, oneInch.address, true, deployConfig.client.wallet, deployConfig.client.public);
}

const deployRocketPool = async (rocketPoolParams, pool, deployConfig) => {
  const rocketPool = await hre.viem.deployContract("RocketPoolAdaptor", [
    rocketPoolParams.assets.rETH,
    rocketPoolParams.wETH,
    pool
  ], deployConfig);
  console.log("RocketPool deployed:", rocketPool.address);
  await addAdpatorSupport(pool, rocketPool.address, true, deployConfig.client.wallet, deployConfig.client.public);

  const assets = [rocketPoolParams.assets.rETH];
  const assetsPrecision = [rocketPoolParams.assetsPrecision.rETH];

  await addAssets(assets, assetsPrecision, 1, pool, deployConfig.client.wallet, deployConfig.client.public);
}

const deployAdaptors = async (pool, adpParams, deployConfig) => {
  const { uniswap: uniswapParams, aave: aaveParams, lido: lidoParams, curve: curveParams, ethena: ethenaParams, beefy: beefyParams, morpho: morphoParams, rocketPool: rocketPoolParams } = adpParams;

  await deployUniswap(uniswapParams, pool, deployConfig);
  await deployAave(aaveParams, pool, deployConfig);
  await deployLido(lidoParams, pool, deployConfig);
  // await deployCurve(curveParams, pool, deployConfig);
  // await deployEthena(ethenaParams, pool, deployConfig);
  // await deployBeefy(beefyParams, pool, deployConfig);
  // await deployMorpho(morphoParams, pool, deployConfig);
  // await deployOneInch(pool, deployConfig);
  // await deployRocketPool(pool, deployConfig);
}

const addAdpatorSupport = async (pool, adpAddress, enable, wallet, client) => {
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

const addAssets = async (assets, assetsPrecision, assetType, poolAddr, wallet, client) => {
  console.log("Adding assets:", assets);
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolAddr,
      abi: poolAbi,
      functionName: "addAssets",
      args: [assetType, assets, assetsPrecision],
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:addAsset", rct.status);
  } catch (e) {
    console.log("Error adding assets:", e);
  }
}

const addAssetsAndRevokers = async (poolProxy, chainParams, commonParams, client, wallet) => {
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolProxy,
      abi: poolAbi,
      functionName: "addAssets",
      args: [chainParams.initAssetType, chainParams.initAssetAddresses, chainParams.initAssetsPrecision],
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

  const verifier = await deployVerifier(deployConfig, wallets[0].account.address);

  const initAddressParams = {
    verifier: verifier,
    adaptorHandler: adaptorHandler.address,
    screener: chainParams.sanctionsList,
    hasher: hasher,
    // mempool: zeroAddress,
    // verificationTrackerService: zeroAddress,
    // nebraVerifier: chainParams.nebraVerifier,
  }

  const args = [
    commonParams.addressTreeDepth,
    commonParams.commitmentTreeDepth,
    commonParams.commitmentTreeQueueSize,
    initAddressParams,
    BigInt(commonParams.withdrawFeeBps),
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

  // @ts-ignore
  const setPoolHash = await wallets[0].writeContract({
    address: adaptorHandler.address,
    abi: adaptorHandlerAbi,
    functionName: "setVeilnyxPool",
    args: [poolProxy.address],
  });
  await client.waitForTransactionReceipt({ hash: setPoolHash });
  console.log("AdaptorHandler: veilnyxPool set to", poolProxy.address);

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
  
  // Deploy Adaptors 
  await deployAdaptors(poolProxy.address, adpParams, deployConfig);

  // ERC4337 infra setup
  const mempoolDummyAddr = "0x1111111111111111111111111111111111111111" as `0x${string}`;
  await deployErc4337Infra(chainParams, poolProxy.address, mempoolDummyAddr, deployConfig);

  // Asset & Revoker Setup
  await addAssetsAndRevokers(poolProxy.address, chainParams, commonParams, client, deployConfig.client.wallet);
};

main().catch(console.error);
