import hre from "hardhat";
import { toFunctionSelector } from "viem";
import { DeployContractConfig } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { deployPaymaster, fundPaymaster } from "./erc4337Infra";
import mainnetDeployment from "../deployments/mainnetFork-1.json";
// constants
const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const poolProxyAbi = hre.artifacts.readArtifactSync("PoolProxy").abi;
const verifierAbi = hre.artifacts.readArtifactSync("Verifier").abi;
const deployedAddresses = mainnetDeployment.addresses as Record<string, `0x${string}`>;
const existingPoolProxy = (process.env.EXISTING_POOL_PROXY_ADDRESS ?? deployedAddresses.poolProxy) as `0x${string}`;
const existingVerifier = (process.env.VERIFIER_ADDRESS ?? deployedAddresses.verifier) as `0x${string}`;
const GATEWAY_ADDRESS = deployedAddresses.gateway;

// Mainnet library addresses from the deployment manifest. The upgrade deploys
// only libraries whose source changed and reuses these addresses for the rest.
const DEPLOYED_LIBS = {
    AssetLogic: deployedAddresses.assetLogic,
    MerkleTreeLogic: deployedAddresses.merkleTreeLogic,
    QueuedMerkleTreeLogic: deployedAddresses.queuedMerkleTreeLogic,
    ShieldedAddressLogic: deployedAddresses.shieldedAddressLogic,
    ShieldedTransactionLogic: deployedAddresses.shieldedTransactionLogic,
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
const getPoolFactory = (libraries = DEPLOYED_LIBS) => hre.ethers.getContractFactory("Pool", {
    libraries: {
        AssetLogic: libraries.AssetLogic,
        MerkleTreeLogic: libraries.MerkleTreeLogic,
        QueuedMerkleTreeLogic: libraries.QueuedMerkleTreeLogic,
        ShieldedAddressLogic: libraries.ShieldedAddressLogic,
        ShieldedTransactionLogic: libraries.ShieldedTransactionLogic,
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
const recordUpgradeLayout = async (libraries: typeof DEPLOYED_LIBS) => {
    console.log("Recording new Pool storage layout in OZ manifest...");
    const PoolFactory = await getPoolFactory(libraries);
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
            ShieldedAddressLogic: commonLibs.shieldedAddress,
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
            ShieldedAddressLogic: commonLibs.shieldedAddress,
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

const bumpVersion = async () => {
    const currentVersion = await client.readContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "version",
    }) as bigint;
    console.log("Pool: current version is", currentVersion.toString());

    // @ts-ignore
    const setVersionHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "setVersion",
        args: [currentVersion + 1n],
    });
    await client.waitForTransactionReceipt({ hash: setVersionHash, timeout: 5 * 60 * 1000 });
    console.log("Pool: version set to", (currentVersion + 1n).toString());
}

const upgradePoolProxy = async (newPoolImpl: `0x${string}`) => {

    /**
    // set pauser calldata
    const pauserAddress = process.env.PAUSER_ADDRESS as `0x${string}`;
    const setPauserCalldata = encodeFunctionData({
        abi: poolAbi,
        functionName: "setPauser",
        args: [pauserAddress],
    });
 */

    // @ts-ignore
    const upgradeCallHash = await wallet.writeContract({
        address: existingPoolProxy,
        abi: poolAbi,
        functionName: "upgradeToAndCall",
        args: [newPoolImpl, "0x"]
    });

    const upgradeRct = await client.waitForTransactionReceipt({ hash: upgradeCallHash, timeout: 5 * 60 * 1000 });
    console.log("rct:Veilnyx Upgraded!!!!!", upgradeRct.status);

    await bumpVersion();
}

const deployCommonLibs = async () => {

    // QueuedMerkleTreeLogic changed in this upgrade. Reuse every unchanged
    // mainnet library to minimize deployment surface and linking mistakes.
    const queuedMerkleTree = await hre.viem.deployContract("QueuedMerkleTreeLogic");
    console.log("QueuedMerkleTreeLogic deployed:", queuedMerkleTree.address);
    /**
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
        asset: DEPLOYED_LIBS.AssetLogic,
        merkleTree: DEPLOYED_LIBS.MerkleTreeLogic,
        queuedMerkleTree: queuedMerkleTree.address as `0x${string}`,
        shieldedAddress: DEPLOYED_LIBS.ShieldedAddressLogic,
        shieldedTransaction: DEPLOYED_LIBS.ShieldedTransactionLogic
    }
}

const registerNewVerifiers = async () => {
    const verifier42Abi = hre.artifacts.readArtifactSync("VerifierTransact42").abi;
    const verifier44Abi = hre.artifacts.readArtifactSync("VerifierTransact44").abi;

    const verifierTransact42 = await hre.viem.deployContract("VerifierTransact42", [], deployConfig);
    console.log("VerifierTransact42 deployed:", verifierTransact42.address);

    const verifierTransact44 = await hre.viem.deployContract("VerifierTransact44", [], deployConfig);
    console.log("VerifierTransact44 deployed:", verifierTransact44.address);

    const txvInfos = [
        { id: 42, selector: toFunctionSelector(verifier42Abi[0]), addr: verifierTransact42.address },
        { id: 44, selector: toFunctionSelector(verifier44Abi[0]), addr: verifierTransact44.address },
    ];

    // @ts-ignore
    const hash = await wallet.writeContract({
        address: existingVerifier,
        abi: verifierAbi,
        functionName: "addTransactionVerifiers",
        args: [txvInfos],
    });
    await client.waitForTransactionReceipt({ hash, timeout: 5 * 60 * 1000 });
    console.log("✅ VerifierTransact42 and VerifierTransact44 registered in Verifier.");
}

const deployAndSetupPaymaster = async () => {
    const paymasterAddress = await deployPaymaster(
        chainParams.entryPoint,
        existingPoolProxy,
        GATEWAY_ADDRESS,
        chainParams,
        deployConfig
    );
    await fundPaymaster(paymasterAddress, wallet, client);
    console.log("Paymaster deployed and funded:", paymasterAddress);
    return paymasterAddress;
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
    await recordUpgradeLayout({
        AssetLogic: commonLibs.asset,
        MerkleTreeLogic: commonLibs.merkleTree,
        QueuedMerkleTreeLogic: commonLibs.queuedMerkleTree,
        ShieldedAddressLogic: commonLibs.shieldedAddress,
        ShieldedTransactionLogic: commonLibs.shieldedTransaction,
    });

    // Extras
    await deployAndSetupPaymaster();
    await registerNewVerifiers();
}

// Recovery path: pool proxy was already upgraded but the script aborted mid-run.
// Usage: RESUME_AFTER_UPGRADE=true npx hardhat run script/upgradePool.ts --network <network>
const resumeAfterUpgrade = async () => {
    await setup();
    await bumpVersion();
    // await registerNewVerifiers();
    // await deployAndSetupPaymaster();
}

const entry = process.env.REGISTER_ONLY === "true"
    ? async () => { await setup(); await registerExistingDeployment(); }
    : main;

entry().catch((err) => { console.log(err) });