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
  Chain
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

const deployAdaptors = async (pool, chainParams, adpParams, wallet, client, tenderlyDeployConfig) => {
  const { uniswap: uniswapConfig, aave: aaveConfig, lido: lidoConfig, ethena: ethenaConfig } = adpParams;

  const uniswap = await hre.viem.deployContract("UniswapV3Adapter", [
    uniswapConfig.uniswapSwapRouter02,
    pool
  ], tenderlyDeployConfig)
  console.log("UniswapV3Adapter deployed:", uniswap.address);
  await addAdpatorSupport(pool, uniswap.address, true, client, wallet);

  const aave = await hre.viem.deployContract("AaveV3Adaptor", [
    aaveConfig.aave,
    pool,
    aaveConfig.aaveStaticTokenFactory
  ], tenderlyDeployConfig);
  console.log("AaveV3Adapter deployed:", aave.address);
  await addAdpatorSupport(pool, aave.address, true, client, wallet);

  const lido = await hre.viem.deployContract("LidoAdaptor", [
    lidoConfig.lido,
    chainParams.initAssetAddresses[0], // wETH
    lidoConfig.stETH, // stETH
    lidoConfig.wstETH, // wstETH
    lidoConfig.withdrawalQueueERC721,
    pool
  ], tenderlyDeployConfig);
  console.log("LidoAdapter deployed:", lido.address);
  await addAdpatorSupport(pool, lido.address, true, client, wallet);

  const curve = await hre.viem.deployContract("CurveNGAdaptor", [
    pool
  ], tenderlyDeployConfig);
  console.log("CurveNGAdp deployed:", curve.address);
  await addAdpatorSupport(pool, curve.address, true, client, wallet);

  const ethena = await hre.viem.deployContract("EthenaAdaptor", [
    ethenaConfig.ethena,
    ethenaConfig.usde,
    pool
  ]);
}

const addAdpatorSupport = async (pool, adpAddress, enable, client, wallet) => {
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
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: paymaster,
      abi: paymasterAbi,
      functionName: "depositToEntryPoint",
      args: [],
      value: parseEther(amount),
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:paymasterFunded", rct.status);
  } catch (error) {
    console.log("Error funding paymaster");
    console.log(error.message);
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
  await deployAdaptors(poolProxy.address, chainParams, adpParams, wallet, client, tenderlyDeployConfig);

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

  await fundPaymaster(paymaster.address, "20", wallet, client);

  // Asset & Revoker Setup
  await addAssetsAndRevokers(poolProxy.address, chainParams, commonParams, client, wallet);
};

main().catch(console.error);
