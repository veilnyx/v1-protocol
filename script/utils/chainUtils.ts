import { defineChain, Chain } from "viem";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { HttpNetworkConfig } from "hardhat/types";

/**
 * Gets the chain configuration for the current network
 * - For standard chains, returns the built-in viem chain object
 * - For custom chains, creates a custom chain definition
 * 
 * @param hre Hardhat Runtime Environment
 * @returns Chain object compatible with viem
 */
export async function getChainForCurrentNetwork(hre: HardhatRuntimeEnvironment): Promise<Chain> {
    const networkName = hre.network.name;
    const chainId = hre.network.config.chainId;

    if (!chainId) {
        throw new Error(`Chain ID not defined for network: ${networkName}`);
    }

    // Try to import standard chain from viem/chains first
    try {
        // This is a dynamic import attempt to get built-in chain definition
        const viemChains = await import("viem/chains");

        // Check if the chain exists in viem's built-in chains
        const standardChain = Object.values(viemChains).find(
            (chain: any) => chain && typeof chain === "object" && "id" in chain && chain.id === chainId
        );

        if (standardChain) {
            console.log(`Using standard chain definition for ${networkName} (chainId: ${chainId})`);
            return standardChain as Chain;
        }
    } catch (error) {
        console.log(`No standard chain definition found for chainId: ${chainId}`);
    }

    // If we're here, this is a custom chain, so we need to create our own definition
    console.log(`Creating custom chain definition for ${networkName} (chainId: ${chainId})`);

    // Get RPC URL from network config
    const rpcUrl = (hre.network.config as HttpNetworkConfig).url || "";
    if (!rpcUrl) {
        throw new Error(`No RPC URL defined for network: ${networkName}`);
    }

    let nativeCurrency = {
        decimals: 18,
        name: "Ether",
        symbol: "ETH",
    };

    if (chainId === 5042002) {
        // Arc Testnet specific configuration
        nativeCurrency.decimals = 6;
        nativeCurrency.name = "USDC";
        nativeCurrency.symbol = "USDC";
    }

    // Define a custom chain
    return defineChain({
        id: chainId,
        name: networkName,
        nativeCurrency,
        rpcUrls: {
            default: {
                http: [rpcUrl as string],
            },
            public: {
                http: [rpcUrl as string],
            },
        },
    });
}
