import dotenv from 'dotenv';
import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-viem';
import '@nomicfoundation/hardhat-foundry';
import '@nomicfoundation/hardhat-ignition';
import '@nomicfoundation/hardhat-ignition-viem';
// import '@nomiclabs/hardhat-solhint';
import 'hardhat-contract-sizer';
// import * as tdly from "@tenderly/hardhat-tenderly";

// tdly.setup({ automaticVerifications: true });
dotenv.config();

const rpcEthereumSepolia = process.env.RPC_ETHEREUM_SEPOLIA as string;
const rpcOptimismSepolia = process.env.RPC_OPTIMISM_SEPOLIA as string;
const rpcTenderlyMainnet = process.env.RPC_TENDERLY_MAINNET as string;
const rpcTenderlyMainnetCustomId = process.env.RPC_TENDERLY_MAINNET_CUSTOM_ID as string;
const privateKeys = [process.env.PRIVATE_KEY as string];
const forkEnabled = process.env.HARDHAT_FORK === 'true';

const config: HardhatUserConfig = {
  solidity: '0.8.24',
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
    optimismSepolia: {
      url: rpcOptimismSepolia,
      accounts: privateKeys,
    },
    tenderlyMainnet: {
      url: rpcTenderlyMainnet,
      accounts: privateKeys,
    },
    tenderlyMainnetCustomId: {
      url: rpcTenderlyMainnetCustomId,
      accounts: privateKeys,
      chainId: 7800,
    },
  },
  contractSizer: {
    runOnCompile: true,
    strict: true,
    unit: 'kB',
  },
};

export default config;
