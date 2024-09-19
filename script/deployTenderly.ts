import hre from "hardhat";
import {
  encodeAbiParameters,
  encodeFunctionData,
  parseAbiParameters,
} from "viem";
import poolModule from "../ignition/modules/pool";
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { deployHasher } from "./hasher";
import { addInitialAssets, registerRevokers } from "./setup";

const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;

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
      selector: "0x6228e166",
      addr: verifierRegister.address
    },
    {
      id: 22,
      selector: "0x3cc08b24",
      addr: verifierTreeUpdate.address
    }
    // Add more TransactionVerifierInfo structs as needed
  ];

  const verifier = await hre.viem.deployContract("Verifier", [
    txVerifierInfos,
    verifierRegister.address,
    verifierTreeUpdate.address,
  ]
    /**
    , {
      libraries: {
        ShieldedTransactionLogic: shieldedTransaction.address,
      }
    }
     */
  );
  console.log("Verifier deployed:", verifier.address);

  return verifier.address;
}

const main = async () => {
  const client = await hre.viem.getPublicClient();
  const chainId = await client.getChainId();
  const commonParams = config.common as CommonParams;
  const chainParams = config[chainId] as ChainParams;

  const wallets = await hre.viem.getWalletClients();
  const wallet = wallets[0];
  const [walletAddress] = await wallet.getAddresses();

  // const address = await hre.viem.deployContract("Address");
  // const safeERC20 = await hre.viem.deployContract("SafeERC20", [], {
  //   libraries: {
  //     Address: address.address,
  //   }
  // });
  const eip712 = await hre.viem.deployContract("EIP712");
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

  // const adaptorHandler = await hre.viem.deployContract("AdaptorHandler", [], {
  //   libraries: {
  //     SafeERC20: safeERC20.address,
  //   }
  // });
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

  /**
  //@ts-ignore
  const owner = await client.readContract({
    address: poolProxy.address,
    abi: poolAbi,
    functionName: "owner",
  });

  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolProxy.address,
      abi: poolAbi,
      functionName: "addAssets",
      args: [chainParams.initAssetType, chainParams.initAssetAddresses],
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct", rct.status);

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
     */
};

main().catch(console.error);
