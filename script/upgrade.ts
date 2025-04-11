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
import { AbiCoder } from "ethers";

// constants
const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const mempoolAbi = hre.artifacts.readArtifactSync("Mempool").abi;
const poolProxyAbi = hre.artifacts.readArtifactSync("PoolProxy").abi;
const existingPoolProxy = `0x${"587539aa53356b15bf919a38d1c8d28e844a1838"}` as `0x${string}`;
const verificationTrackerService = `0x${"75a4dA1697aF884c99724474d26F2EAe23cc58Bc"}` as `0x${string}`;
const nebraVerifierSepolia = `0x${"3B946743DEB7B6C97F05B7a31B23562448047E3E"}` as `0x${string}`;
const MEMPOOL_EXIT_FEES: bigint = BigInt(45_000_000_000_0000); // 500k gas @ 0.9 gwei = 0.00045 ETH

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

const deployMempoolImplAndProxy = async (shieldedTransactionLogic: `0x${string}`, assetLogic: `0x${string}`, gateway: `0x${string}`) => {
    console.log("Starting to deploy new Mempool");
    const enumerableSet = await hre.viem.deployContract("EnumerableSet");
    console.log("EnumerableSet deployed:", enumerableSet.address);
    const safeERC20 = await hre.viem.deployContract("SafeERC20");

    const mempoolImpl = await hre.viem.deployContract("Mempool", [], {
        libraries: {
            EnumerableSet: enumerableSet.address,
            SafeERC20: safeERC20.address,
            ShieldedTransactionLogic: shieldedTransactionLogic,
            AssetLogic: assetLogic
        },
    });
    console.log("New Mempool deployed:", mempoolImpl.address);

    const args = [
        existingPoolProxy,
        MEMPOOL_EXIT_FEES,
        verificationTrackerService,
        nebraVerifierSepolia,
        gateway
    ];

    const initData = encodeFunctionData({
        abi: mempoolAbi,
        functionName: "initialize",
        args: args as any,
    });

    const mempoolProxy = await hre.viem.deployContract("MempoolProxy", [
        mempoolImpl.address,
        initData,
    ]);
    console.log("MempoolProxy deployed:", mempoolProxy.address);
    return mempoolProxy.address;
}

const deployPoolImpl = async (commonLibs: any) => {
    console.log("Starting to deploy new Pool");
    const eip712 = await hre.viem.deployContract("EIP712");
    console.log("EIP712 deployed:", eip712.address);


    const shieldedAddress = await hre.viem.deployContract(
        "ShieldedAddressLogic",
        [],
        {
            libraries: {
                MerkleTreeLogic: commonLibs.merkleTree,
            },
        }
    );
    console.log("ShieldedAddressLogic deployed:", shieldedAddress.address);

    const poolImpl = await hre.viem.deployContract("Pool", [], {
        libraries: {
            EIP712: eip712.address,
            AssetLogic: commonLibs.asset,
            MerkleTreeLogic: commonLibs.merkleTree,
            QueuedMerkleTreeLogic: commonLibs.queuedMerkleTree,
            ShieldedAddressLogic: shieldedAddress.address,
            ShieldedTransactionLogic: commonLibs.shieldedTransaction,
        },
    });
    console.log("New Pool deployed:", poolImpl.address);
    /// @dev we dont have to again add assets/revokers/adaptorHandler/adaptor support in an upgrade as the state is retained in PoolProxy itself.
    return poolImpl.address;
};

const upgradePoolProxy = async (newPoolImpl: `0x${string}`, mempool: `0x${string}`, verificationTrackerService: `0x${string}`) => {
    // Create calldata for PoolImpl::reinitialize(address mempool_, address verificationTrackerService_)
    const args = [
        mempool,
        verificationTrackerService
    ];

    const reinitializeCallData = encodeFunctionData({
        abi: poolAbi,
        functionName: "reinitialize",
        args: args as any,
    });

    // upgrade existing PoolProxy to point to the latest pool
    /// @notice the initData in the args should be 0x if PoolProxy does not need reinitialisation (as if case of no changes to the Pool proxy storage). The upgraded Pool will just continue to use the existing state of the PoolProxy as the state is managed there. Pool impl. is just a logic layer that functions in context of PoolProxy.
    /// @notice But in case of reinitilisation required due to any new state changes, the initData should be the calldata for the reinitialisation function in the PoolImpl contract.
    // @ts-ignore
    const upgradeCallHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "upgradeToAndCall",
        args: [newPoolImpl, reinitializeCallData]
    });

    const upgradeRct = await client.waitForTransactionReceipt({ hash: upgradeCallHash });
    console.log("rct:upgrade", upgradeRct.status);
}

const deployCommonLibs = async () => {
    // deploying common libraries
    const asset = await hre.viem.deployContract("AssetLogic");
    console.log("AssetLogic deployed:", asset.address);

    const merkleTree = await hre.viem.deployContract("MerkleTreeLogic");
    console.log("MerkleTreeLogic deployed:", merkleTree.address);

    const queuedMerkleTree = await hre.viem.deployContract(
        "QueuedMerkleTreeLogic"
    );
    console.log("QueuedMerkleTreeLogic deployed:", queuedMerkleTree.address);

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

    return {
        asset: asset.address,
        merkleTree: merkleTree.address,
        queuedMerkleTree: queuedMerkleTree.address,
        shieldedTransaction: shieldedTransaction.address
    }
}

const main = async () => {
    await setup();

    // Common Libs
    const commonLibs = await deployCommonLibs();

    // ERC4337 infra
    const erc4337Contracts = await deployErc4337Infra(chainParams, existingPoolProxy, deployConfig);

    const mempoolProxy = await deployMempoolImplAndProxy(commonLibs.shieldedTransaction, commonLibs.asset, erc4337Contracts.gateway);
    const newPoolImpl = await deployPoolImpl(commonLibs);
    await upgradePoolProxy(newPoolImpl, mempoolProxy, verificationTrackerService);
}

main().catch((err) => { console.log(err) });
