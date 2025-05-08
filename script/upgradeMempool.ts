
import hre from "hardhat";
import { loadConfigs, ChainParams, CommonParams } from "./configs";
import { DeployContractConfig } from '@nomicfoundation/hardhat-viem/types';


const config = loadConfigs();
const mempoolAbi = hre.artifacts.readArtifactSync("Mempool").abi;

let client: any;
let chainId: number;
let wallet: any;
let commonParams: CommonParams;
let wallets: any[];
let walletAddress: string;
let chainParams: ChainParams;
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

const deployMempoolImpl = async (shieldedTransactionLogicAddr: `0x${string}`) => {
    console.log("Starting to deploy new Mempool");

    // deploy MempoolValidator
    const mempoolValidator = await hre.viem.deployContract("MempoolValidator", [], {
        libraries: {
            ShieldedTransactionLogic: shieldedTransactionLogicAddr
        }
    });
    console.log("MempoolValidator deployed:", mempoolValidator.address);

    const mempoolImpl = await hre.viem.deployContract("Mempool", [], {
        libraries: {
            MempoolValidator: mempoolValidator.address
        },
    });

    console.log("MempoolImpl deployed:", mempoolImpl.address);
    return mempoolImpl.address;
}


const main = async () => {
    await setup();

    const existingMempoolProxy = "0x9642346eE64cf65D67f324Ff7Ec24AfF903Fbe2d" as `0x${string}`;
    const shieldedTransactionLogicAddr = "0xb28096f5fe1463dd806947603d8269759b807c04" as `0x${string}`;
    const newMempoolImpl = await deployMempoolImpl(shieldedTransactionLogicAddr);

    const upgradeCallHash = await wallet.writeContract({
        address: existingMempoolProxy,
        abi: mempoolAbi,
        functionName: "upgradeToAndCall",
        args: [newMempoolImpl, "0x"],
    });

    const upgradeRct = await client.waitForTransactionReceipt({ hash: upgradeCallHash });
    console.log("rct:Labyrinth MEMPOOL Upgraded!!!!!", upgradeRct.status);
}

main().catch((err) => { console.log(err) });