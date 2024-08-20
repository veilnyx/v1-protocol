import dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-viem";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ignition";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-ignition-viem";

dotenv.config();

const rpcEthereumSepolia = process.env.RPC_ETHEREUM_SEPOLIA as string;
const rpcOptimismSepolia = process.env.RPC_OPTIMISM_SEPOLIA as string;
const privateKeys = [process.env.PRIVATE_KEY as string];

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    ethereumSepolia: {
      url: rpcEthereumSepolia,
      accounts: privateKeys,
    },
    optimismSepolia: {
      url: rpcOptimismSepolia,
      accounts: privateKeys,
    },
  },
};

export default config;
