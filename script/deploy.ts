import hre from "hardhat";
import { ethers, upgrades } from "hardhat";
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
const mempoolAbi = hre.artifacts.readArtifactSync("Mempool").abi;
const PROOF_SUB_MEMPOOL_EXIT_FEES: bigint = BigInt(75_000_000_000_0000); // 375k gas @ 2 gwei = 0.00075 ETH
const verificationTrackerService = `0x${"75a4dA1697aF884c99724474d26F2EAe23cc58Bc"}` as `0x${string}`;
const nebraVerifierSepolia = `0x${"3B946743DEB7B6C97F05B7a31B23562448047E3E"}` as `0x${string}`;
const zeroAddr = "0x0000000000000000000000000000000000000000" as `0x${string}`;

const deployMempoolProxy = async (pool: `0x${string}`, shieldedTransactionLogicAddr: `0x${string}`, gateway: `0x${string}`): Promise<`0x${string}`> => {
  console.log("Starting to deploy new Mempool");

  // deploy MempoolValidator
  const mempoolValidator = await hre.viem.deployContract("MempoolValidator", [], {
    libraries: {
      ShieldedTransactionLogic: shieldedTransactionLogicAddr
    }
  });
  console.log("MempoolValidator deployed:", mempoolValidator.address);

  // deploying using Hardhat Proxy deploy plugin
  const mempoolImpl = await ethers.getContractFactory("Mempool", {
    libraries: {
      MempoolValidator: mempoolValidator.address
    }
  });

  const args = [
    pool,
    PROOF_SUB_MEMPOOL_EXIT_FEES,
    verificationTrackerService,
    nebraVerifierSepolia,
    gateway
  ];

  const mempoolProxy = await upgrades.deployProxy(mempoolImpl, args, {
    kind: "uups",
    unsafeAllow: ["external-library-linking"]
  });

  await mempoolProxy.waitForDeployment();
  const mempoolProxyAddr = await mempoolProxy.getAddress();
  console.log("MempoolProxy deployed:", mempoolProxyAddr);
  return mempoolProxyAddr as `0x${string}`;
}

const updateGatewayAndPoolInMempool = async (deployConfig, mempool: `0x${string}`, gateway: `0x${string}`, pool: `0x${string}`) => {

  // @ts-ignore
  const updatePoolTxHash = await deployConfig.client.wallet.writeContract({
    address: mempool,
    abi: mempoolAbi,
    functionName: "updatePoolAddress",
    args: [pool]
  });

  const upgradePoolRct = await deployConfig.client.public.waitForTransactionReceipt({ hash: updatePoolTxHash });
  console.log("rct:updatePoolAddress in Mempool", upgradePoolRct.status);

  // @ts-ignore
  const updateGatewayHash = await deployConfig.client.wallet.writeContract({
    address: mempool,
    abi: mempoolAbi,
    functionName: "updateGatewayContract",
    args: [gateway]
  });

  const upgradeGatewayRct = await deployConfig.client.public.waitForTransactionReceipt({ hash: updateGatewayHash });
  console.log("rct:updateGatewayContract in Mempool", upgradeGatewayRct.status);
}

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

  // Pool and Gateway contract addr will be updated at the end
  const mempoolProxy = await deployMempoolProxy(zeroAddr, shieldedTransaction.address, zeroAddr);

  // POOL DEPLOYMENT
  let poolProxy;
  {

    const libraries = {
      EIP712: eip712.address,
      AssetLogic: asset.address,
      MerkleTreeLogic: merkleTree.address,
      QueuedMerkleTreeLogic: queuedMerkleTree.address,
      ShieldedAddressLogic: shieldedAddress.address,
      ShieldedTransactionLogic: shieldedTransaction.address,
    }

    const poolFactory = await ethers.getContractFactory("Pool", {
      libraries: libraries
    });

    const { hasher } = await deployHasher(wallet, client, deployConfig);
    console.log("Hasher deployed:", hasher);

    const verifier = await deployVerifier(deployConfig);

    const initAddressParams = {
      mempool: mempoolProxy,
      verifier: verifier,
      adaptorHandler: adaptorHandler.address,
      screener: chainParams.sanctionsList,
      hasher: hasher,
      verificationTrackerService: verificationTrackerService
    }

    const args = [
      commonParams.addressTreeDepth,
      commonParams.commitmentTreeDepth,
      commonParams.commitmentTreeQueueSize,
      initAddressParams,
      BigInt(commonParams.withdrawFeeBps),
    ];

    poolProxy = await upgrades.deployProxy(poolFactory, args, {
      kind: "uups",
      unsafeAllow: ["external-library-linking"],
    });
    console.log("PoolProxy deployed:", poolProxy.address);
  }

  // Asset support and Revoker registrations
  try {
    //@ts-ignore
    const hash = await wallet.writeContract({
      address: poolProxy.address,
      abi: poolAbi,
      functionName: "addAssets",
      args: [chainParams.initAssetType, chainParams.initAssetAddresses],
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
  const erc4337Contracts = await deployErc4337Infra(chainParams, poolProxy.address, mempoolProxy, deployConfig);

  await updateGatewayAndPoolInMempool(deployConfig, mempoolProxy, erc4337Contracts.gateway, poolProxy.address);

  // Register Labyrinth's circuits with Nebra
  // await registerCircuitsOnNebra();
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

  const deployConfig: DeployContractConfig = {
    client: {
      public: client,
      wallet: wallet
    }
  }

  // const mempoolProxy = await deployMempoolProxy(`0x0369cb46f2cbe32c775a2f00177d8dbf84fcb4af` as `0x${string}`, `0xb28096f5fe1463dd806947603d8269759b807c04` as `0x${string}`, `0xf0335a55ef61a57cd4d726a1a53e0143835168b0` as `0x${string}`);

  const mempoolProxy = `0x9642346eE64cf65D67f324Ff7Ec24AfF903Fbe2d` as `0x${string}`;
  const poolProxy = `0x0369cb46f2cbe32c775a2f00177d8dbf84fcb4af` as `0x${string}`;
  // ERC4337 infra
  const erc4337Contracts = await deployErc4337Infra(chainParams, poolProxy, mempoolProxy, deployConfig);

  await updateGatewayAndPoolInMempool(deployConfig, mempoolProxy, erc4337Contracts.gateway, poolProxy);

};

main1().catch(console.error);
