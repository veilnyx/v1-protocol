import hre from "hardhat";
import { encodeFunctionData } from "viem";
import { DeployContractConfig } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { deployErc4337Infra } from "./erc4337Infra";

// constants
const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const mempoolAbi = hre.artifacts.readArtifactSync("Mempool").abi;
const poolProxyAbi = hre.artifacts.readArtifactSync("PoolProxy").abi;
const existingPoolProxy = `0x0369cb46f2cbe32c775a2f00177d8dbf84fcb4af` as `0x${string}`; // devnet parallel pool proxy to test upgrade. @todo replace with real pool proxy address
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

const deployMempoolImplAndProxy = async (shieldedTransactionLogicAddr: `0x${string}`, assetLogicAddr: `0x${string}`, gateway: `0x${string}`) => {
    console.log("Starting to deploy new Mempool");
    // const enumerableSet = await hre.viem.deployContract("EnumerableSet");
    // console.log("EnumerableSet deployed:", enumerableSet.address);
    // const safeERC20 = await hre.viem.deployContract("SafeERC20");

    // deploy NebraLib
    const nebraLib = await hre.viem.deployContract("NebraLib");
    console.log("NebraLib deployed:", nebraLib.address);

    // deploy MempoolValidator
    const mempoolValidator = await hre.viem.deployContract("MempoolValidator", [], {
        libraries: {
            ShieldedTransactionLogic: shieldedTransactionLogicAddr
        }
    });
    console.log("MempoolValidator deployed:", mempoolValidator.address);

    const mempoolImpl = await hre.viem.deployContract("Mempool", [], {
        libraries: {
            // EnumerableSet: enumerableSet.address,
            // SafeERC20: safeERC20.address,
            ShieldedTransactionLogic: shieldedTransactionLogicAddr,
            AssetLogic: assetLogicAddr,
            MempoolValidator: mempoolValidator.address,
            NebraLib: nebraLib.address,
        },
    });

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

const upgradePoolProxy = async (newPoolImpl: `0x${string}`) => {

    // upgrade existing PoolProxy to point to the latest pool
    /// @notice the initData in the args should be 0x if PoolProxy does not need reinitialisation (as if case of no changes to the Pool proxy storage). The upgraded Pool will just continue to use the existing state of the PoolProxy as the state is managed there. Pool impl. is just a logic layer that functions in context of PoolProxy.
    /// @notice But in case of reinitilisation required due to any new state changes, the initData should be the calldata for the reinitialisation function in the PoolImpl contract.
    // @ts-ignore
    const upgradeCallHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "upgradeToAndCall",
        args: [newPoolImpl, "0x"]
    });

    const upgradeRct = await client.waitForTransactionReceipt({ hash: upgradeCallHash });
    console.log("rct:Veilnyx Upgraded!!!!!", upgradeRct.status);

    // Set protocol version
    // @ts-ignore
    const setVersionHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "setVersion",
        args: [commonParams.protocolVersion + 1], // incrementing version since upgrading
    });
    await client.waitForTransactionReceipt({ hash: setVersionHash });
    console.log("Pool: version set to", commonParams.protocolVersion + 1);
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
            }
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

const updateGatewayInMempool = async (mempool: `0x${string}`, gateway: `0x${string}`) => {
    const args = [
        gateway
    ];

    // @ts-ignore
    const updateGatewayHash = await wallet.writeContract({
        address: mempool,
        abi: mempoolAbi,
        functionName: "updateGatewayContract",
        args: [gateway]
    });

    const upgradeGatewayRct = await client.waitForTransactionReceipt({ hash: updateGatewayHash });
    console.log("rct:upgradeGatewayRct", upgradeGatewayRct.status);
}

const main = async () => {
    await setup();

    // Common Libs
    const commonLibs = await deployCommonLibs();

    // Mempool Proxy
    /// @dev The gateway contract address will be a zero addr, but will be updated using MempoolProxy::updateGatewayContract() function after the deployment of the ERC4337 infrastructure. This is due to a circular dependency between the mempool and the ERC4337 infrastructure. The mempool needs to be deployed first, and then the ERC4337 infrastructure can be deployed with Gateway => Mempool. Finally, the mempool needs to be updated with the Gateway contract address.
    const mempoolProxy = await deployMempoolImplAndProxy(commonLibs.shieldedTransaction, commonLibs.asset, "0x0000000000000000000000000000000000000000" as `0x${string}`);

    // ERC4337 infra
    const erc4337Contracts = await deployErc4337Infra(chainParams, existingPoolProxy, mempoolProxy, deployConfig);

    await updateGatewayInMempool(mempoolProxy, erc4337Contracts.gateway);

    const newPoolImpl = await deployPoolImpl(commonLibs);

    await upgradePoolProxy(newPoolImpl);
}

const upgradePoolOnly = async () => {
    await setup();

    const mempoolProxy = `0x9642346eE64cf65D67f324Ff7Ec24AfF903Fbe2d` as `0x${string}`;
    const commonLibs = {
        asset: `0x18c58a90d190953e0cb08c7075a5f4e7718616fe` as `0x${string}`,
        merkleTree: `0x220c00d601a39da4f92873929295f0f70488fd2c` as `0x${string}`,
        queuedMerkleTree: `0x77bd63353b2ef38eca6517585c727cb96ab64894` as `0x${string}`,
        shieldedTransaction: `0xb28096f5fe1463dd806947603d8269759b807c04` as `0x${string}`
    }

    const newPoolImpl = await deployPoolImpl(commonLibs);
    await upgradePoolProxy(newPoolImpl);
}

// main().catch((err) => { console.log(err) });
upgradePoolOnly();
