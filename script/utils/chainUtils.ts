import { defineChain, Chain } from "viem";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { HttpNetworkConfig } from "hardhat/types";

/**
 * True when the node behind the current network is a local development chain (anvil, or Hardhat's
 * in-process EVM) rather than a real one.
 *
 * `hre.network.config.forking?.enabled` only covers Hardhat's built-in forking. A fork served by an
 * external anvil process looks like any other HTTP network, so fall back to asking the node what it
 * is: anvil answers `anvil/v1.4.0`, Hardhat answers `HardhatNetwork/...`.
 *
 * Used both to skip real-network-only steps (Etherscan verification) and, more importantly, as the
 * safety gate for networks that carry a real chain id but are meant to be forks.
 */
export async function isDevelopmentNode(hre: HardhatRuntimeEnvironment): Promise<boolean> {
    if ((hre.network.config as any).forking?.enabled === true) {
        return true;
    }

    try {
        const clientVersion = (await hre.network.provider.send("web3_clientVersion")) as string;
        return /anvil|hardhat/i.test(clientVersion);
    } catch {
        // A node that will not answer web3_clientVersion is treated as real — this gate must fail
        // closed, since callers use it to decide whether deploying is safe.
        return false;
    }
}

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
