import hre from "hardhat";

import { DeployContractConfig, KeyedClient } from '@nomicfoundation/hardhat-viem/types';
import { loadConfigs, ChainParams } from "./configs";
import { getChainForCurrentNetwork } from "./utils/chainUtils";
import { deployPaymaster, fundPaymaster } from "./erc4337Infra";

const config = loadConfigs();
const main = async () => {
    const chain = await getChainForCurrentNetwork(hre);
    console.log("Deploying to chain:", chain);

    const client = await hre.viem.getPublicClient({ chain });

    const chainId = await client.getChainId();
    const wallets = await hre.viem.getWalletClients({ chain });

    const deployConfig: DeployContractConfig = {
        client: {
            public: client,
            wallet: wallets[0]
        } as KeyedClient
    }

    const chainParams = config[chainId] as ChainParams;

    const poolAddress = `0xef7585dfcdb91b0dc9fc9f920c4fb72bfb7b3e1f` as `0x${string}`;
    const senderAddress = `0x6465a561c22f7286f1ca97d5f754627b5823b0b9` as `0x${string}`; // Gateway Contract

    // New Paymaster deployment
    const paymasterAddress = await deployPaymaster(
        chainParams.entryPoint,
        poolAddress, senderAddress, chainParams, deployConfig);

    await fundPaymaster(paymasterAddress, wallets[0], client);
}

main().catch((error) => {
    console.error("Error in deployPaymaster script:", error);
    process.exitCode = 1;
});