import hre from "hardhat";
// import { tenderly } from 'hardhat';
import {
  encodeAbiParameters,
  encodeFunctionData,
  parseAbiParameters,
  defineChain,
  parseEther,
  toFunctionSelector,
  Hex
} from "viem";
import poolModule from "../ignition/modules/pool";
import { loadConfigs, ChainParams, AdaptorParams, CommonParams } from "./configs";
import { deployHasher } from "./hasher";
import { addInitialAssets, registerRevokers } from "./setup";

const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const paymasterAbi = hre.artifacts.readArtifactSync("Paymaster").abi;
const verifier21Abi = hre.artifacts.readArtifactSync("VerifierTransact21").abi;
const verifier22Abi = hre.artifacts.readArtifactSync("VerifierTransact22").abi;


const deployVerifier = async () => {
  const verifierRegister = await hre.viem.deployContract("VerifierRegister");
  console.log("VerifierRegister deployed:", verifierRegister.address);

  const verifierTreeUpdate = await hre.viem.deployContract("VerifierTreeUpdate");
  console.log("VerifierTreeUpdate deployed:", verifierTreeUpdate.address);

  // Tx Verifiers
  const verifierTransact21 = await hre.viem.deployContract("VerifierTransact21");
  console.log("VerifierTransact21 deployed:", verifierTransact21.address);

  const verifierTransact22 = await hre.viem.deployContract("VerifierTransact22");
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
  ]
  );
  console.log("Verifier deployed:", verifier.address);

  return verifier.address;
}

const deployAdaptors = async (pool, chainParams, adpParams, wallet, client) => {
  const { uniswap: uniswapConfig, aave: aaveConfig, lido: lidoConfig } = adpParams;

  const uniswap = await hre.viem.deployContract("UniswapV3Adapter", [
    uniswapConfig.uniswapSwapRouter02,
    pool
  ])
  console.log("UniswapV3Adapter deployed:", uniswap.address);
  await addAdpatorSupport(pool, uniswap.address, true, client, wallet);

  const aave = await hre.viem.deployContract("AaveV3Adaptor", [
    aaveConfig.aave,
    pool,
    aaveConfig.aaveStaticTokenFactory
  ]);
  console.log("AaveV3Adapter deployed:", aave.address);
  await addAdpatorSupport(pool, aave.address, true, client, wallet);

  const lido = await hre.viem.deployContract("LidoAdaptor", [
    lidoConfig.lido,
    chainParams.initAssetAddresses[0], // wETH
    lidoConfig.stETH, // stETH
    lidoConfig.wstETH, // wstETH
    lidoConfig.withdrawalQueueERC721,
    pool
  ]);
  console.log("LidoAdapter deployed:", lido.address);
  await addAdpatorSupport(pool, lido.address, true, client, wallet);

  const curve = await hre.viem.deployContract("CurveNGAdaptor", [
    pool
  ]);
  await addAdpatorSupport(pool, curve.address, true, client, wallet);
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

const defineChainViem = () => {
  const labyrinthChain = defineChain({
    name: "Labyrinth Mainnet Simulation v1.0",
    id: 7800,
    nativeCurrency: {
      decimals: 18,
      name: 'Ether',
      symbol: 'ETH',
    },
    rpcUrls: {
      default: {
        http: [process.env.RPC_TENDERLY_MAINNET as string]
      },
    },
  });

  return labyrinthChain;
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

const addAssetsAndRevokers = async (poolProxy, chainParams, commonParams, client) => {
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolProxy.address,
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
        address: poolProxy.address,
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
  // const labyrinthChain = defineChainViem();
  const client = await hre.viem.getPublicClient();
  const chainId = await client.getChainId();
  const commonParams = config.common as CommonParams;
  const adpParams = config.adpConfig[chainId] as AdaptorParams;
  const chainParams = config[chainId] as ChainParams;

  const wallets = await hre.viem.getWalletClients();
  const wallet = wallets[0];
  const [walletAddress] = await wallet.getAddresses();
  const eip712 = await hre.viem.deployContract("EIP712");
  // const eip712Rct = await client.waitForTransactionReceipt({ hash: eip712.address });
  // await tenderly.verify({
  //   address: eip712Rct.contractAddress,
  //   name: "EIP712",
  // });
  console.log("EIP712 deployed:", eip712.address);
  const asset = await hre.viem.deployContract("AssetLogic");
  console.log("AssetLogic deployed:", asset.address);
  const merkleTree = await hre.viem.deployContract("MerkleTreeLogic");
  console.log("MerkleTreeLogic deployed:", merkleTree.address);
  const queuedMerkleTree = await hre.viem.deployContract(
    "QueuedMerkleTreeLogic"
  );
  console.log("QueuedMerkleTreeLogic deployed:", queuedMerkleTree.address);

  const shieldedAddress = await hre.viem.deployContract(
    "ShieldedAddressLogic",
    [],
    {
      libraries: {
        MerkleTreeLogic: merkleTree.address,
      },
    }
  );
  console.log("ShieldedAddressLogic deployed:", shieldedAddress.address);

  const shieldedTransaction = await hre.viem.deployContract(
    "ShieldedTransactionLogic",
    [],
    {
      libraries: {
        AssetLogic: asset.address,
        MerkleTreeLogic: merkleTree.address,
        QueuedMerkleTreeLogic: queuedMerkleTree.address,
      },
    }
  );
  console.log("ShieldedTransactionLogic deployed:", shieldedTransaction.address);
  const adaptorHandler = await hre.viem.deployContract("AdaptorHandler");
  console.log("AdaptorHandler deployed: ", adaptorHandler.address);

  const poolImpl = await hre.viem.deployContract("Pool", [], {
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

  const { hasher } = await deployHasher(wallet, client);
  console.log("Hasher deployed:", hasher);

  const verifier = await deployVerifier();

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
  ]);
  console.log("PoolProxy deployed:", poolProxy.address);

  // Deploy Adaptors 
  await deployAdaptors(poolProxy.address, chainParams, adpParams, wallet, client);

  // ERC4337 infra setup
  const gateway = await hre.viem.deployContract("Gateway", [
    chainParams.entryPoint,
    chainParams.wToken,
    poolProxy.address,
  ]);
  console.log("Gateway deployed:", gateway.address);

  const paymaster = await hre.viem.deployContract("Paymaster", [
    chainParams.entryPoint,
    gateway.address,
  ]);
  console.log("Paymaster deployed:", paymaster.address);

  await fundPaymaster(paymaster.address, "20", wallet, client);

  // Asset & Revoker Setup
  await addAssetsAndRevokers(poolProxy.address, chainParams, commonParams, client);
};

main().catch(console.error);
