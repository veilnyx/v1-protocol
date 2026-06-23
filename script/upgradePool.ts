import hre from "hardhat";
import { encodeFunctionData } from "viem";
import { DeployContractConfig } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { deployErc4337Infra } from "./erc4337Infra";
import { deploy } from "@openzeppelin/hardhat-upgrades/dist/utils";

// constants
const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const poolProxyAbi = hre.artifacts.readArtifactSync("PoolProxy").abi;
const existingPoolProxy = `0xd971f6c35e7a71f25d912cd652ba182ca0778f5b` as `0x${string}`;
const verificationTrackerService = `0x${"75a4dA1697aF884c99724474d26F2EAe23cc58Bc"}` as `0x${string}`;
const nebraVerifierSepolia = `0x${"3B946743DEB7B6C97F05B7a31B23562448047E3E"}` as `0x${string}`;

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

const deployPoolImpl = async (commonLibs: any) => {
    console.log("Starting to deploy new Pool");
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
            AssetLogic: commonLibs.asset,
            MerkleTreeLogic: commonLibs.merkleTree,
            QueuedMerkleTreeLogic: commonLibs.queuedMerkleTree,
            ShieldedAddressLogic: shieldedAddress.address,
            ShieldedTransactionLogic: commonLibs.shieldedTransaction,
        },
    });
    console.log("New Pool deployed:", poolImpl.address);

    // Add the 2-minute delay here
    console.log("Waiting 2 minutes for the block explorer to index the contract...");
    await new Promise((resolve) => setTimeout(resolve, 2 * 60 * 1000)); // 2 minutes in milliseconds

    // Verification //
    const poolImplVerificationObj = {
        address: poolImpl.address,
        constructorArguments: [],
        libraries: {
            AssetLogic: commonLibs.asset,
            MerkleTreeLogic: commonLibs.merkleTree,
            QueuedMerkleTreeLogic: commonLibs.queuedMerkleTree,
            ShieldedAddressLogic: shieldedAddress.address,
            ShieldedTransactionLogic: commonLibs.shieldedTransaction,
        },
    }
    try {
        await hre.run("verify:verify", poolImplVerificationObj)
        console.log("Verified:", poolImplVerificationObj.address);
    } catch (e: any) {
        if (e.message?.includes("Already Verified") || e.message?.includes("already verified")) {
            console.log("Already verified:", poolImplVerificationObj.address);
        } else {
            console.error("Verification failed for", poolImplVerificationObj.address, e.message);
        }
    }

    /// @dev we dont have to again add assets/revokers/adaptorHandler/adaptor support in an upgrade as the state is retained in PoolProxy itself.
    return poolImpl.address;
};

const upgradePoolProxy = async (newPoolImpl: `0x${string}`) => {

    // @ts-ignore
    const upgradeCallHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "upgradeToAndCall",
        args: [newPoolImpl, "0x"]
    });

    const upgradeRct = await client.waitForTransactionReceipt({ hash: upgradeCallHash, timeout: 5 * 60 * 1000 });
    console.log("rct:Veilnyx Upgraded!!!!!", upgradeRct.status);

    // Set protocol version
    // @ts-ignore
    const setVersionHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "setVersion",
        args: [commonParams.protocolVersion + 1n], // incrementing version since upgrading
    });
    await client.waitForTransactionReceipt({ hash: setVersionHash, timeout: 5 * 60 * 1000 });
    console.log("Pool: version set to", commonParams.protocolVersion + 1n);
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
                AssetLogic: asset.address as `0x${string}`,
                MerkleTreeLogic: merkleTree.address as `0x${string}`,
                QueuedMerkleTreeLogic: queuedMerkleTree.address as `0x${string}`,
            }
        }
    );
    console.log("ShieldedTransactionLogic deployed:", shieldedTransaction.address);

    return {
        asset: asset.address as `0x${string}`,
        merkleTree: merkleTree.address as `0x${string}`,
        queuedMerkleTree: queuedMerkleTree.address as `0x${string}`,
        shieldedTransaction: shieldedTransaction.address
    }
}

const main = async () => {
    await setup();

    // Common Libs
    const commonLibs = await deployCommonLibs();

    // ERC4337 infra
    const erc4337Contracts = await deployErc4337Infra(chainParams, existingPoolProxy, deployConfig);

    const newPoolImpl = await deployPoolImpl(commonLibs);

    await upgradePoolProxy(newPoolImpl);
}

main().catch((err) => { console.log(err) });
