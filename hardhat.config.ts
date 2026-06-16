import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-viem";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ignition";
import "@nomicfoundation/hardhat-ignition-viem";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-verify";
// import * as tdly from "@tenderly/hardhat-tenderly";

// tdly.setup({ automaticVerifications: true });
dotenv.config();

const rpcEthereumSepolia = process.env.RPC_ETHEREUM_SEPOLIA as string;
const etherscanApiKey = process.env.ETHERSCAN_API_KEY as string;
const rpcOptimismSepolia = process.env.RPC_OPTIMISM_SEPOLIA as string;
const rpcTenderlyMainnet = process.env.RPC_TENDERLY_MAINNET as string;
const rpcVeilnyxTestnet = process.env.RPC_VEILNYX_TESTNET as string;
const rpcArcTestnet = process.env.RPC_ARC_TESTNET as string;
const rpcTenderlyMainnetCustomId = process.env.RPC_TENDERLY_MAINNET_CUSTOM_ID as string;
const privateKeys = [process.env.PRIVATE_KEY as string];
const veilnyxPrivateKeys = [process.env.VEILNYX_TEST_PRIV_KEY as string];
const forkEnabled = process.env.HARDHAT_FORK === "true";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10_00_000,
          },
        },
      },
    ],
    // Mirror the foundry.toml `compilation_restrictions` override: Pool sits
    // close to the EIP-170 24,576-byte limit, so compile it with low runs to
    // shrink runtime bytecode at the cost of a tiny gas overhead on the thin
    // dispatch shell. All other contracts keep the global 1M runs.
    overrides: {
      "src/core/Pool.sol": {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      forking: {
        url: rpcOptimismSepolia,
        enabled: forkEnabled,
        blockNumber: 16229898,
      },
    },
    sepolia: {
      url: rpcEthereumSepolia,
      accounts: privateKeys,
      chainId: 11155111
    },
    optimismSepolia: {
      url: rpcOptimismSepolia,
      accounts: privateKeys,
      chainId: 11155420
    },
    tenderlyMainnet: {
      url: rpcTenderlyMainnet,
      accounts: privateKeys,
      chainId: 1
    },
    tenderlyMainnetCustomId: {
      url: rpcTenderlyMainnetCustomId,
      accounts: privateKeys,
      chainId: 7800
    },
    veilnyxTestnet: {
      url: rpcVeilnyxTestnet,
      accounts: veilnyxPrivateKeys,
      chainId: 34244
    },
    arcTestnet: {
      url: rpcArcTestnet,
      accounts: privateKeys,
      chainId: 5042002
    }
  },
  contractSizer: {
    runOnCompile: true,
    strict: true,
    unit: "kB"
  },
  etherscan: {
    apiKey: {
      sepolia: etherscanApiKey,
    },
    customChains: [
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=11155111",
          browserURL: "https://sepolia.etherscan.io",
        },
      },
    ],
  } as any
};

export default config;
