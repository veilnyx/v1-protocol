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

const rpcEthereumMainnet = process.env.RPC_ETHEREUM_MAINNET as string;
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
      // Serves `deploy:test` / `upgrade:test` only. Mainnet dry-runs use the `mainnetFork` network
      // below instead — Hardhat's in-process forking cannot fork current mainnet at all.
      forking: {
        url: rpcOptimismSepolia,
        enabled: forkEnabled,
        blockNumber: 16229898,
      },
    },
    mainnet: {
      url: rpcEthereumMainnet,
      accounts: privateKeys,
      chainId: 1
    },
    // Deployment dry-runs against a local anvil mainnet fork:
    //   npm run fork:mainnet                    (terminal 1, keep running)
    //   npm run deployCoreWithAdp:mainnet:fork  (terminal 2)
    //
    // chainId 1 is the point: the deploy scripts resolve their config by `client.getChainId()`,
    // so this is what makes them load the real mainnet entry from config.json instead of a copy.
    // Hardhat's own in-process forking cannot be used for this — its bundled EDR predates recent
    // mainnet hardforks and panics on current block headers ("Must be present as this is not a
    // pending block") — and it would report chainId 31337 regardless.
    //
    // `url` is hardcoded to localhost and `accounts` is left as "remote" (anvil's pre-funded,
    // unlocked accounts) on purpose: this network carries mainnet's chain id, so it must never be
    // one env var away from broadcasting real transactions with a real key. deployCoreWithAdp.ts
    // additionally refuses to run against any node that is not anvil/hardhat.
    mainnetFork: {
      url: "http://127.0.0.1:8546",
      chainId: 1
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
  // Consumed by @nomicfoundation/hardhat-verify (`hre.run("verify:verify")`).
  // `apiKey` and `customChains` are both keyed by the *network name* as declared
  // in `networks` above, so every network we verify on needs an entry in each.
  // The scripts also read `customChains[].urls.apiURL` directly for raw Etherscan
  // V2 API calls (see verifyProxy in script/deployCoreWithAdp.ts).
  etherscan: {
    apiKey: {
      mainnet: etherscanApiKey,
      sepolia: etherscanApiKey,
    },
    customChains: [
      {
        network: "mainnet",
        chainId: 1,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=1",
          browserURL: "https://etherscan.io",
        },
      },
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
