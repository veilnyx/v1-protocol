import hre from "hardhat";
import {
    encodeAbiParameters,
    encodeFunctionData,
    parseAbiParameters,
    Hex,
    Chain
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
const poolProxyAbi = hre.artifacts.readArtifactSync("PoolProxy").abi;
let client: any;
let chainId: number;
let commonParams: CommonParams;
let chainParams: ChainParams;
let wallets: any[];
let wallet: any;
let walletAddress: string;
let deployConfig: DeployContractConfig;


const setup = async () => {
    client = await hre.viem.getPublicClient();
    chainId = await client.getChainId();
    commonParams = config.common as CommonParams;
    chainParams = config[chainId] as ChainParams;

    wallets = await hre.viem.getWalletClients();
    wallet = wallets[0];
    [walletAddress] = await wallet.getAddresses();
    console.log("Using wallet:", walletAddress);
    deployConfig = {
        client: {
            public: client,
            wallet: wallet
        }
    }
}

const deployPoolImpl = async () => {
    console.log("Starting to deploy new Pool");
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
    console.log("New Pool deployed:", poolImpl.address);

    return poolImpl.address;
};

const upgradeProxy = async () => {
    const existingPoolProxy = "0x7E53C283730C0Fa9d38f263BD1f51cB6B4D68efE" as `0x${string}`;
    const upgradedPoolImpl = await deployPoolImpl();

    // upgrade existing PoolProxy to point to the latest pool
    /// @notice the initData in the args should be 0x this time, because PoolProxy has already been initialised. The upgraded Pool will just continue to use the existing state of the PoolProxy as the state is managed there. Pool impl. is just a logic layer that functions in context of PoolProxy.
    // @ts-ignore
    const upgradeCallHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "upgradeToAndCall",
        args: [upgradedPoolImpl, "0x"]
    });

    const upgradeRct = await client.waitForTransactionReceipt({ hash: upgradeCallHash });
    console.log("rct:upgrade", upgradeRct.status);
}

const main = async () => {
    await setup();
    await upgradeProxy();
}

main().catch((err) => { console.log(err) });
