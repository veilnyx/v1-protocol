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
  Hex
} from "viem";

import { DeployContractConfig } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams, AdaptorParams, CommonParams } from "./configs";
import { deployHasher } from "./hasher";
import { privateKeyToAccount } from 'viem/accounts';

const config = loadConfigs();
const privateKey = process.env.PRIVATE_KEY as `0x{string}`;
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
const verifier21Abi = hre.artifacts.readArtifactSync("VerifierTransact21").abi;
const verifier22Abi = hre.artifacts.readArtifactSync("VerifierTransact22").abi;


const deployVerifier = async (tenderlyDeployConfig) => {
  const verifierRegister = await hre.viem.deployContract("VerifierRegister", [], tenderlyDeployConfig);
  console.log("VerifierRegister deployed:", verifierRegister.address);

  const verifierTreeUpdate = await hre.viem.deployContract("VerifierTreeUpdate", [], tenderlyDeployConfig);
  console.log("VerifierTreeUpdate deployed:", verifierTreeUpdate.address);

  // Tx Verifiers
  const verifierTransact21 = await hre.viem.deployContract("VerifierTransact21", [], tenderlyDeployConfig);
  console.log("VerifierTransact21 deployed:", verifierTransact21.address);

  const verifierTransact22 = await hre.viem.deployContract("VerifierTransact22", [], tenderlyDeployConfig);
  console.log("VerifierTransact22 deployed:", verifierTransact22.address);

  // Prepare the TransactionVerifierInfo array
  const txVerifierInfos = [
    {
      id: 21,
      selector: toFunctionSelector(verifier21Abi[0]),
      addr: verifierTransact21.address
    },
    {
      id: 22,
      selector: toFunctionSelector(verifier22Abi[0]),
      addr: verifierTransact22.address
    }
    // Add more TransactionVerifierInfo structs as needed
  ];

  const verifier = await hre.viem.deployContract("Verifier", [
    txVerifierInfos,
    verifierRegister.address,
    verifierTreeUpdate.address,
  ],
    tenderlyDeployConfig
  );
  console.log("Verifier deployed:", verifier.address);

  return verifier.address;
}

const deployUniswap = async (uniswapParams, pool, tenderlyDeployConfig) => {
  const uniswap = await hre.viem.deployContract("UniswapV3Adapter", [
    uniswapParams.uniswapSwapRouter02,
    pool
  ], tenderlyDeployConfig)
  console.log("UniswapV3Adapter deployed:", uniswap.address);
  await addAdpatorSupport(pool, uniswap.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployAave = async (aaveParams, pool, tenderlyDeployConfig) => {
  const aave = await hre.viem.deployContract("AaveV3Adaptor", [
    aaveParams.aave,
    pool,
    aaveParams.aaveStaticTokenFactory
  ], tenderlyDeployConfig);
  console.log("AaveV3Adapter deployed:", aave.address);
  await addAdpatorSupport(pool, aave.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);

  const assets = [aaveParams.assets.staticAWeth, aaveParams.assets.staticAUsdc];
  await addAssets(assets, 1, pool, wallet, client);
}

const deployLido = async (lidoParams, pool, tenderlyDeployConfig) => {
  const lido = await hre.viem.deployContract("LidoAdaptor", [
    lidoParams.lido,
    lidoParams.wETH, // wETH
    lidoParams.stETH, // stETH
    lidoParams.wstETH, // wstETH
    lidoParams.withdrawalQueueERC721,
    pool
  ], tenderlyDeployConfig);
  console.log("LidoAdapter deployed:", lido.address);
  await addAdpatorSupport(pool, lido.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);

  const assets = [lidoParams.assets.wstEth];
  await addAssets(assets, 1, pool, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployCurve = async (curveParams, pool, tenderlyDeployConfig) => {
  const curve = await hre.viem.deployContract("CurveNGAdaptor", [
    pool
  ], tenderlyDeployConfig);
  console.log("CurveNGAdp deployed:", curve.address);
  await addAdpatorSupport(pool, curve.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);

  const assets = [curveParams.assets.usdt, curveParams.assets.crvUsd, curveParams.assets.crvUsdUsdtLPToken, curveParams.assets.crvUsdSusdeLPToken];
  await addAssets(assets, 1, pool, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployEthena = async (ethenaParams, pool, tenderlyDeployConfig) => {
  const ethena = await hre.viem.deployContract("EthenaAdaptor", [
    ethenaParams.ethena,
    ethenaParams.usde,
    pool
  ], tenderlyDeployConfig);
  console.log("Ethena deployed:", ethena.address);
  await addAdpatorSupport(pool, ethena.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);

  const assets = [ethenaParams.assets.usde, ethenaParams.assets.sUsde];
  await addAssets(assets, 1, pool, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployBeefy = async (beefyParams, pool, tenderlyDeployConfig) => {
  const beefy = await hre.viem.deployContract("BeefyV7Adaptor", [
    pool
  ], tenderlyDeployConfig);
  console.log("Beefy deployed:", beefy.address);
  await addAdpatorSupport(pool, beefy.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);

  const assets = [beefyParams.assets.mooCurveCrvUSDsUSDe];
  await addAssets(assets, 1, pool, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployMorpho = async (morphoParams, pool, tenderlyDeployConfig) => {
  const morpho = await hre.viem.deployContract("MorphoVaultAdaptor", [
    pool
  ], tenderlyDeployConfig);
  console.log("Morpho deployed:", morpho.address);
  await addAdpatorSupport(pool, morpho.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);

  const assets = [morphoParams.assets.gauntletWETHPrimeVault];
  await addAssets(assets, 1, pool, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployOneInch = async (pool, tenderlyDeployConfig) => {
  const oneInch = await hre.viem.deployContract("OneInchAdaptor", [
    pool
  ], tenderlyDeployConfig);
  console.log("OneInch deployed:", oneInch.address);
  await addAdpatorSupport(pool, oneInch.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployRocketPool = async (rocketPoolParams, pool, tenderlyDeployConfig) => {
  const rocketPool = await hre.viem.deployContract("RocketPoolAdaptor", [
    rocketPoolParams.rocketSwapRouter,
    rocketPoolParams.assets.rETH,
    rocketPoolParams.wETH,
    pool
  ], tenderlyDeployConfig);
  console.log("RocketPool deployed:", rocketPool.address);
  await addAdpatorSupport(pool, rocketPool.address, true, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);

  const assets = [rocketPoolParams.assets.rETH];
  await addAssets(assets, 1, pool, tenderlyDeployConfig.client.wallet, tenderlyDeployConfig.client.public);
}

const deployAdaptors = async (pool, adpParams, tenderlyDeployConfig) => {
  const { uniswap: uniswapParams, aave: aaveParams, lido: lidoParams, curve: curveParams, ethena: ethenaParams, beefy: beefyParams, morpho: morphoParams, rocketPool: rocketPoolParams } = adpParams;

  await deployUniswap(uniswapParams, pool, tenderlyDeployConfig);
  await deployAave(aaveParams, pool, tenderlyDeployConfig);
  await deployLido(lidoParams, pool, tenderlyDeployConfig);
  await deployCurve(curveParams, pool, tenderlyDeployConfig);
  await deployEthena(ethenaParams, pool, tenderlyDeployConfig);
  await deployBeefy(beefyParams, pool, tenderlyDeployConfig);
  await deployMorpho(morphoParams, pool, tenderlyDeployConfig);
  await deployOneInch(pool, tenderlyDeployConfig);
  await deployRocketPool(rocketPoolParams, pool, tenderlyDeployConfig);
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

const createTenderlyChain = (): Chain => {
  const tenderlyChain = defineChain({
    name: "Labyrinth Mainnet Simulation v1.0",
    id: 7800,
    nativeCurrency: {
      decimals: 18,
      name: 'Ether',
      symbol: 'ETH',
    },
    rpcUrls: {
      default: {
        http: [process.env.RPC_TENDERLY_MAINNET_CUSTOM_ID as string]
      },
    },
  });

  return tenderlyChain;
}

const fundPaymaster = async (paymaster, amount, wallet, client) => {
  let rct;
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: paymaster,
      abi: paymasterAbi,
      functionName: "depositToEntryPoint",
      args: [],
      value: parseEther('20'),
    });

    rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:paymasterFunded", rct.status);
  } catch (error) {
    console.log("Error funding paymaster");
    console.log(error.message);
    console.log("Error rct:", rct);
  }
}

const addAssets = async (assets, assetType, poolAddr, wallet, client) => {
  console.log("Adding assets:", assets);
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolAddr,
      abi: poolAbi,
      functionName: "addAssets",
      args: [assetType, assets],
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
      args: [chainParams.initAssetType, chainParams.initAssetAddresses],
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
  const tenderlyChain = createTenderlyChain();
  const client = await hre.viem.getPublicClient({
    chain: tenderlyChain
  });
  const chainId = await client.getChainId();
  const wallet = createWalletClient({
    chain: tenderlyChain,
    transport: http(tenderlyChain.rpcUrls.default.http[0]),
    account: privateKeyToAccount(privateKey)
  });

  const tenderlyDeployConfig: DeployContractConfig = {
    //@ts-ignore
    client: {
      public: client,
      wallet: wallet
    }
  }

  const commonParams = config.common as CommonParams;
  const adpParams = config.adpConfig[chainId] as AdaptorParams;
  const chainParams = config[chainId] as ChainParams;

  // Add assets
  // addAssets(["0x9AbD7F0782CDe1DBd1F0519C35c961b6A724c2a5" as Hex], 1, "0x9163043b553aDeF9fE44b088922560cfBFdEC51b" as Hex, wallet, client);

  // individual adp deployment
  // deployMorpho(adpParams.morpho, "0x9163043b553aDeF9fE44b088922560cfBFdEC51b" as Hex, tenderlyDeployConfig);

  const eip712 = await hre.viem.deployContract("EIP712", [], tenderlyDeployConfig);
  console.log("EIP712 deployed:", eip712.address);

  const asset = await hre.viem.deployContract("AssetLogic", [], tenderlyDeployConfig);
  console.log("AssetLogic deployed:", asset.address);
  const merkleTree = await hre.viem.deployContract("MerkleTreeLogic", [], tenderlyDeployConfig);
  console.log("MerkleTreeLogic deployed:", merkleTree.address);
  const queuedMerkleTree = await hre.viem.deployContract(
    "QueuedMerkleTreeLogic", [], tenderlyDeployConfig
  );
  console.log("QueuedMerkleTreeLogic deployed:", queuedMerkleTree.address);

  const shieldedAddress = await hre.viem.deployContract(
    "ShieldedAddressLogic",
    [],
    {
      client: tenderlyDeployConfig.client,
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
      client: tenderlyDeployConfig.client,
      libraries: {
        AssetLogic: asset.address,
        MerkleTreeLogic: merkleTree.address,
        QueuedMerkleTreeLogic: queuedMerkleTree.address,
      },
    }
  );
  console.log("ShieldedTransactionLogic deployed:", shieldedTransaction.address);
  const adaptorHandler = await hre.viem.deployContract("AdaptorHandler", [], tenderlyDeployConfig);
  console.log("AdaptorHandler deployed: ", adaptorHandler.address);

  const poolImpl = await hre.viem.deployContract("Pool", [], {
    client: tenderlyDeployConfig.client,
    libraries: {
      EIP712: eip712.address,
      AssetLogic: asset.address,
      MerkleTreeLogic: merkleTree.address,
      QueuedMerkleTreeLogic: queuedMerkleTree.address,
      ShieldedAddressLogic: shieldedAddress.address,
      ShieldedTransactionLogic: shieldedTransaction.address,
    },
  });
  console.log("Pool deployed:", poolImpl.address);

  const { hasher } = await deployHasher(wallet, client, tenderlyDeployConfig);
  console.log("Hasher deployed:", hasher);

  const verifier = await deployVerifier(tenderlyDeployConfig);

  const args = [
    commonParams.addressTreeDepth,
    commonParams.commitmentTreeDepth,
    commonParams.commitmentTreeQueueSize,
    verifier,
    adaptorHandler.address,
    chainParams.sanctionsList,
    hasher,
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
  ], tenderlyDeployConfig);
  console.log("PoolProxy deployed:", poolProxy.address);

  // Deploy Adaptors 
  await deployAdaptors(poolProxy.address, adpParams, tenderlyDeployConfig);

  // ERC4337 infra setup
  const gateway = await hre.viem.deployContract("Gateway", [
    chainParams.entryPoint,
    chainParams.wToken,
    poolProxy.address,
  ], tenderlyDeployConfig);
  console.log("Gateway deployed:", gateway.address);

  const paymaster = await hre.viem.deployContract("Paymaster", [
    chainParams.entryPoint,
    gateway.address,
  ], tenderlyDeployConfig);
  console.log("Paymaster deployed:", paymaster.address);

  // skipping funding of paymaster on Tenderly
  /// @todo: uncomment for other networks
  // await fundPaymaster(paymaster.address, "20", wallet, client);

  // Asset & Revoker Setup
  await addAssetsAndRevokers(poolProxy.address, chainParams, commonParams, client, wallet);
};

main().catch(console.error);
