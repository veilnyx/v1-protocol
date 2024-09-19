import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-viem";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ignition";
import "@nomicfoundation/hardhat-ignition-viem";
import "hardhat-contract-sizer";
// import * as tdly from "@tenderly/hardhat-tenderly";

// tdly.setup({ automaticVerifications: true });
dotenv.config();

const rpcEthereumSepolia = process.env.RPC_ETHEREUM_SEPOLIA as string;
const rpcOptimismSepolia = process.env.RPC_OPTIMISM_SEPOLIA as string;
const rpcTenderlyMainnet = process.env.RPC_TENDERLY_MAINNET as string;
const privateKeys = [process.env.PRIVATE_KEY as string];
const forkEnabled = process.env.HARDHAT_FORK === "true";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      forking: {
        url: rpcOptimismSepolia,
        enabled: forkEnabled,
        blockNumber: 16229898,
      },
    },
    ethereumSepolia: {
      url: rpcEthereumSepolia,
      accounts: privateKeys,
    },
    tenderlyMainnet:{
      url: rpcTenderlyMainnet,
      accounts: privateKeys,
    },
    optimismSepolia: {
      url: rpcOptimismSepolia,
      accounts: privateKeys,
    },
    tenderlyMainnet: {
      url: rpcTenderlyMainnet,
      accounts: privateKeys,
      chainId: 1
    },
  },
  // tenderly: {
  //   username: "0xShiven",
  //   project: "Labyrinth Integrations",
  //   privateVerification: false // if true, contracts will be verified privately, if false, contracts will be verified publicly
  // },
  contractSizer: {
    runOnCompile: true,
    strict: true,
    unit: "kB"
  }
};

export default config;
