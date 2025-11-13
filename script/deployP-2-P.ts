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

    const eip712 = await hre.viem.deployContract("EIP712", [], deployConfig);
    console.log("EIP712 deployed:", eip712.address);
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
                EIP712: eip712.address,
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

        const verifier = await deployVerifier(deployConfig);

        const initAddressParams = {
            mempool: zeroAddress,
            verifier: verifier,
            adaptorHandler: zeroAddress,
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
    /* const erc4337Contracts = */
    await deployErc4337Infra(chainParams, poolProxy.address, zeroAddress, deployConfig);
};

main().catch(console.error);
