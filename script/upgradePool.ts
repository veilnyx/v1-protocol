import hre from "hardhat";
import { encodeFunctionData } from "viem";
import { DeployContractConfig } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { deployErc4337Infra } from "./erc4337Infra";
// constants
const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const poolProxyAbi = hre.artifacts.readArtifactSync("PoolProxy").abi;
const existingPoolProxy = process.env.EXISTING_POOL_PROXY_ADDRESS as `0x${string}`;

// Deployed library addresses — update these when redeploying libraries.
const DEPLOYED_LIBS = {
    AssetLogic: `0x976b21916c51303a23b6d292e7750fdadabb2b26` as `0x${string}`,
    MerkleTreeLogic: `0x3e89cfd1ef7999de608d76e59ca4dfbef07b2cc5` as `0x${string}`,
    QueuedMerkleTreeLogic: `0x0b84b501e07ee4012f2ef134d65976aa4611cd31` as `0x${string}`,
    ShieldedAddressLogic: `0x45bee23b29db93b60ea488e54a0b348a6fef1a9b` as `0x${string}`,
    ShieldedTransactionLogic: `0xaaed44a5d1dec54e79ba1c666264f8e5ec6d576d` as `0x${string}`,
};
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

// Returns a linked Pool factory. OZ validates the storage layout from the
// compiled artifact, but ethers still requires library addresses at factory
// creation time due to the unlinked bytecode check.
const getPoolFactory = () => hre.ethers.getContractFactory("Pool", {
    libraries: {
        AssetLogic: DEPLOYED_LIBS.AssetLogic,
        MerkleTreeLogic: DEPLOYED_LIBS.MerkleTreeLogic,
        QueuedMerkleTreeLogic: DEPLOYED_LIBS.QueuedMerkleTreeLogic,
        ShieldedAddressLogic: DEPLOYED_LIBS.ShieldedAddressLogic,
        ShieldedTransactionLogic: DEPLOYED_LIBS.ShieldedTransactionLogic,
    },
});

// Validates the current Pool source's storage layout against the OZ manifest
// (.openzeppelin/<chainId>.json) before any bytes are deployed on-chain.
// Throws on any incompatible change (slot reorder, type change, array replacing
// a mapping, field deletion, etc.).
const validateStorageUpgrade = async () => {
    console.log("Validating Pool storage layout compatibility...");
    const PoolFactory = await getPoolFactory();
    await hre.upgrades.validateUpgrade(existingPoolProxy, PoolFactory, {
        kind: "uups",
        unsafeAllowLinkedLibraries: true,
        unsafeAllowRenames: true
    });
    console.log("✅ Storage layout validation passed.");
};

// One-time bootstrap: imports the existing deployed proxy into the OZ manifest
// (.openzeppelin/<chainId>.json) so future upgrades have a baseline to validate
// against. Run this once with the source code matching what is currently live
// on-chain, then commit the generated manifest file to git.
// Usage: REGISTER_ONLY=true npx hardhat run script/upgradePool.ts --network <network> (with REGISTER_ONLY=true in .env)
const registerExistingDeployment = async () => {
    console.log("Registering existing Pool proxy in OZ manifest...");
    const PoolFactory = await getPoolFactory();
    await hre.upgrades.forceImport(existingPoolProxy, PoolFactory, {
        kind: "uups",
    });
    console.log("✅ Proxy registered — commit .openzeppelin/ to git.");
};

// Updates the manifest baseline after a successful upgrade so the next run
// validates against the layout just deployed. Commit .openzeppelin/ after this.
const recordUpgradeLayout = async () => {
    console.log("Recording new Pool storage layout in OZ manifest...");
    const PoolFactory = await getPoolFactory();
    await hre.upgrades.forceImport(existingPoolProxy, PoolFactory, {
        kind: "uups",
    });
    console.log("✅ Layout recorded — commit .openzeppelin/ to git.");
};

const deployPoolImpl = async (commonLibs: any) => {
    /**
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
 */
    const poolImpl = await hre.viem.deployContract("Pool", [], {
        libraries: {
            AssetLogic: commonLibs.asset,
            MerkleTreeLogic: commonLibs.merkleTree,
            QueuedMerkleTreeLogic: commonLibs.queuedMerkleTree,
            ShieldedAddressLogic: `0x45bee23b29db93b60ea488e54a0b348a6fef1a9b` as `0x${string}`,
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
            ShieldedAddressLogic: `0x45bee23b29db93b60ea488e54a0b348a6fef1a9b` as `0x${string}`,
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

    // set pauser calldata
    const pauserAddress = process.env.PAUSER_ADDRESS as `0x${string}`;
    const setPauserCalldata = encodeFunctionData({
        abi: poolAbi,
        functionName: "setPauser",
        args: [pauserAddress],
    });


    // @ts-ignore
    const upgradeCallHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "upgradeToAndCall",
        args: [newPoolImpl, setPauserCalldata]
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
    /**
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
 */
    return {
        asset: `0x976b21916c51303a23b6d292e7750fdadabb2b26` as `0x${string}`,
        merkleTree: `0x3e89cfd1ef7999de608d76e59ca4dfbef07b2cc5` as `0x${string}`,
        queuedMerkleTree: `0x0b84b501e07ee4012f2ef134d65976aa4611cd31` as `0x${string}`,
        shieldedTransaction: `0xaaed44a5d1dec54e79ba1c666264f8e5ec6d576d` as `0x${string}`
    }
}

const main = async () => {
    await setup();

    await validateStorageUpgrade();

    // Common Libs
    const commonLibs = await deployCommonLibs();

    // ERC4337 infra
    // const erc4337Contracts = await deployErc4337Infra(chainParams, existingPoolProxy, deployConfig);

    const newPoolImpl = await deployPoolImpl(commonLibs);

    await upgradePoolProxy(newPoolImpl);

    await recordUpgradeLayout();
}

const entry = process.env.REGISTER_ONLY === "true"
    ? async () => { await setup(); await registerExistingDeployment(); }
    : main;

entry().catch((err) => { console.log(err) });
