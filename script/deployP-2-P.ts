// The purpose of this script is to deploy the Veilnyx protocol core features focused on P-2-P transactions using Stable coins only.
// This deploy script will skip:
// 1. Proof aggregation features
// 2. Integration adaptors
// 3. Any tokens apart from gas and stable coins will be skipped

import hre from "hardhat";
import {
    encodeAbiParameters,
    encodeFunctionData,
    parseAbiParameters,
    zeroAddress
} from "viem";
import { DeployContractConfig, KeyedClient } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { deployHasher } from "./hasher";
import { deployVerifier } from "./verifier";
import { deployErc4337Infra } from "./erc4337Infra";
import { getChainForCurrentNetwork } from "./utils/chainUtils";

const config = loadConfigs();
const poolAbi = hre.artifacts.readArtifactSync("Pool").abi;
const verificationTrackerService = `0x${"75a4dA1697aF884c99724474d26F2EAe23cc58Bc"}` as `0x${string}`;

const main = async () => {
    // Get the appropriate chain definition for the current network

    const chain = await getChainForCurrentNetwork(hre);
    console.log("Deploying to chain:", chain);

    // Use the chain definition when creating clients
    const client = await hre.viem.getPublicClient({ chain });
    const wallets = await hre.viem.getWalletClients({ chain });
    const wallet = wallets[0];

    const commonParams = config.common as CommonParams;
    const chainParams = config[chain.id] as ChainParams;

    const deployConfig: DeployContractConfig = {
        client: {
            public: client,
            wallet: wallet
        } as KeyedClient,
        gasPrice: BigInt(200_000_000_000), // 200 gwei
        maxFeePerGas: BigInt(200_000_000_000), // 200 gwei
    }

    const asset = await hre.viem.deployContract("AssetLogic", [], deployConfig);
    console.log("AssetLogic deployed:", asset.address);
    const merkleTree = await hre.viem.deployContract("MerkleTreeLogic", [], deployConfig);
    console.log("MerkleTreeLogic deployed:", merkleTree.address);
    const queuedMerkleTree = await hre.viem.deployContract(
        "QueuedMerkleTreeLogic",
        [],
        deployConfig
    );
    console.log("QueuedMerkleTreeLogic deployed:", queuedMerkleTree.address);

    const shieldedAddress = await hre.viem.deployContract(
        "ShieldedAddressLogic",
        [],
        {
            libraries: {
                MerkleTreeLogic: merkleTree.address,
            },
            ...deployConfig
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
            ...deployConfig
        },
    );
    console.log("ShieldedTransactionLogic deployed:", shieldedTransaction.address);

    // POOL DEPLOYMENT
    let poolProxy;
    {
        const poolImpl = await hre.viem.deployContract("Pool", [], {
            libraries: {
                AssetLogic: asset.address,
                MerkleTreeLogic: merkleTree.address,
                QueuedMerkleTreeLogic: queuedMerkleTree.address,
                ShieldedAddressLogic: shieldedAddress.address,
                ShieldedTransactionLogic: shieldedTransaction.address,
            },
            ...deployConfig
        });
        console.log("Pool deployed:", poolImpl.address);

        const { hasher } = await deployHasher(wallet, client, deployConfig);
        console.log("Hasher deployed:", hasher);

        const verifier = await deployVerifier(deployConfig, wallet.account.address);

        const initAddressParams = {
            verifier: verifier,
            adaptorHandler: zeroAddress,
            screener: chainParams.sanctionsList,
            hasher: hasher,
            pauser: commonParams.pauserAddress, // zeroAddress leaves pausing exclusive to the owner
        }

        const ONE_HOUR = 3600n;
        const configParams = {
            withdrawFeeBps: BigInt(commonParams.withdrawFeeBps),
            tvlLimitUsd: BigInt(5_000e6),    // $5,000 (6-decimal precision)
            minDepositUsd: BigInt(2e6),      // $2 (6-decimal precision)
            maxDepositUsd: BigInt(200e6),    // $200 (6-decimal precision)
            priceFeedStalenessThreshold: ONE_HOUR * 2n, // 2 hours in seconds
            nativeWToken: chainParams.nativeWToken,      // wrapped native token (e.g. WETH) for native ETH deposits
        };

        const args = [
            commonParams.commitmentTreeQueueSize,
            initAddressParams,
            configParams,
        ];

        const initData = encodeFunctionData({
            abi: poolAbi,
            functionName: "initialize",
            args: args as any,
        });

        poolProxy = await hre.viem.deployContract("PoolProxy", [
            poolImpl.address,
            initData,
        ], deployConfig);
        console.log("PoolProxy deployed:", poolProxy.address);

        // Set protocol version
        // @ts-ignore
        const setVersionHash = await wallet.writeContract({
            address: poolProxy.address,
            abi: poolAbi,
            functionName: "setVersion",
            args: [commonParams.protocolVersion],
        });
        await client.waitForTransactionReceipt({ hash: setVersionHash });
        console.log("Pool: version set to", commonParams.protocolVersion);
    }

    // pause the protocol immediately after deployment to prevent any interactions before the setup is complete
    // @ts-ignore
    const pauseHash = await wallets[0].writeContract({
        address: poolProxy.address,
        abi: poolAbi,
        functionName: "pause",
    });
    await client.waitForTransactionReceipt({ hash: pauseHash });
    console.log("Pool: paused");

    // transfer ownership to a multisig or a Gnosis Safe after deployment. For testing purposes, we can keep the ownership to the deployer wallet
    // @ts-ignore
    const transferOwnershipHash = await wallets[0].writeContract({
        address: poolProxy.address,
        abi: poolAbi,
        functionName: "transferOwnership",
        args: [zeroAddress], // set to zeroAddress to keep ownership to deployer wallet for testing. Update with multisig or Gnosis Safe address for production deployment.
    });
    await client.waitForTransactionReceipt({ hash: transferOwnershipHash });
    console.log("Pool: ownership transferred");

    // Asset support and Revoker registrations
    try {
        //@ts-ignore
        const hash = await wallet.writeContract({
            address: poolProxy.address,
            abi: poolAbi,
            functionName: "addAssets",
            args: [chainParams.initAssetType, chainParams.initAssetAddresses, chainParams.initAssetsPrecision],
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
    /* const erc4337Contracts = */
    await deployErc4337Infra(chainParams, poolProxy.address, deployConfig);
};

main().catch(console.error);
