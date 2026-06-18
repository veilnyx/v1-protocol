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

    const poolAddress = `0xd971f6c35e7a71f25d912cd652ba182ca0778f5b` as `0x${string}`;
    const senderAddress = `0x1d6549f20d81fcf5b12982ac8742acba623af0cd` as `0x${string}`; // Gateway Contract
    
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