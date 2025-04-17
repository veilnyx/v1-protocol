import hre from "hardhat";
import {
  encodeAbiParameters,
  encodeFunctionData,
  parseAbiParameters,
} from "viem";
import { DeployContractConfig } from '@nomicfoundation/hardhat-viem/types';
import poolModule from "../ignition/modules/pool";
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { deployHasher } from "./hasher";
import { deployVerifier } from "./verifier";
import { deployErc4337Infra } from "./erc4337Infra";
import { registerCircuitsOnNebra } from "./registerCircuitsOnNebra";
import { addInitialAssets, registerRevokers } from "./setup";

const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;

const main1 = async () => {
  const client = await hre.viem.getPublicClient();
  const chainId = await client.getChainId();
  const commonParams = config.common as CommonParams;
  const chainParams = config[chainId] as ChainParams;

  const wallets = await hre.viem.getWalletClients();
  const wallet = wallets[0];
  const [walletAddress] = await wallet.getAddresses();
  const deployConfig: DeployContractConfig = {
    client: {
      public: client,
      wallet: wallet
    }
  }

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

  const adaptorHandler = await hre.viem.deployContract("AdaptorHandler", [], deployConfig);
  console.log("AdaptorHandler deployed: ", adaptorHandler.address);

  const zeroAddress = "0x0000000000000000000000000000000000000000";
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

  const { hasher } = await deployHasher(wallet, client, deployConfig);
  console.log("Hasher deployed:", hasher);

  const verifier = await deployVerifier(deployConfig);

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

  // Asset support and Revoker registrations
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolProxy.address,
      abi: poolAbi,
      functionName: "addAssets",
      args: [chainParams.initAssetType, chainParams.initAssetAddresses, chainParams.initAssetPrecision],
    });

    const rct = await client.waitForTransactionReceipt({ hash });
    console.log("rct:addAssets", rct.status);

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

  // ERC4337 infra
  await deployErc4337Infra(chainParams, poolProxy.address, deployConfig);

  // Register Labyrinth's circuits with Nebra
  await registerCircuitsOnNebra();
};

const main = async () => {
  const client = await hre.viem.getPublicClient();
  const wallets = await hre.viem.getWalletClients();
  const wallet = wallets[0];
  const [walletAddress] = await wallet.getAddresses();
  const chainId = await client.getChainId();
  const commonParams = config.common as CommonParams;
  const chainParams = config[chainId] as ChainParams;

  console.log("Running deployment on chain:", chainId);
  console.log("Deployer address:", walletAddress);

  const parameters = {
    pool: { ...commonParams },
    hasher: {
      poseidonT3: chainParams.poseidonT3,
      poseidonT4: chainParams.poseidonT4,
    },
    screener: {
      sanctionsList: chainParams.sanctionsList,
    },
  };

  const { poolProxy } = await hre.ignition.deploy(poolModule, {
    parameters,
  });
  const poolAddress = poolProxy.address;
  console.log("Pool deployed at:", poolAddress);

  // SETUP ASSETS
  await addInitialAssets(poolAddress);

  // REGISTER REVOKERS
  await registerRevokers(poolAddress);
};

main1().catch(console.error);
