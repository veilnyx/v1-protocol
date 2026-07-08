//@ts-ignore
import * as snarkJs from "snarkjs";
import * as ethers from "ethers";
import dotenv from 'dotenv';
import path, { parse } from 'path';
import {
  createTestClient,
  http,
  keccak256,
  padHex,
  parseEther,
  parseUnits,
  stringToBytes,
  toHex,
  Hex,
  PublicClient
} from "viem";
import { foundry } from "viem/chains";
import { Core, CoreOptions } from "@labyrinthac/core";
import MerkleTree from "fixed-merkle-tree";
import { fp, poseidonHash } from "@labyrinthac/babyjubjub";
import { UpaClient, UpaInstanceDescriptor } from "@nebrazkp/upa/sdk";
import { toBigInt } from "@labyrinthac/utils";
import {
  MockAddressResolver,
  MockNotesSource,
  MockTreeSource,
} from "./mockServices";
import { circuits } from "./zk";
import { fixture } from "./fixture";
import { TransactionOptions } from "@labyrinthac/shared-types";

const {
  sender: { account: senderAccount },
  revokerPublicKey,
  encryptionPublicKey,
  addressTreeDepth,
  commitmentTreeDepth,
} = fixture;

dotenv.config({
  path: path.resolve(__dirname, '../../../.env')
});

const zeroElement = fp.create(BigInt(keccak256(stringToBytes("zero")))).toString() as Hex;
const hashFunction = (a: any, b: any) =>
  padHex(toHex(poseidonHash([toBigInt(a), toBigInt(b)])), { size: 32 });

export const commitmentTree = new MerkleTree(commitmentTreeDepth, [], {
  zeroElement,
  hashFunction,
});
export const addressTree = new MerkleTree(addressTreeDepth, [], {
  zeroElement,
  hashFunction,
});

export const getSDKInstance = async () => {
  const client = createTestClient({
    chain: foundry,
    mode: "anvil",
    transport: http(),
  });

  const commitmentTreeSource = new MockTreeSource(commitmentTree);
  const addressTreeSource = new MockTreeSource(addressTree);
  const addressResolver = new MockAddressResolver();
  const notesSource = new MockNotesSource();

  addressTreeSource.insert(senderAccount.rootAddress);

  const coreOpt: CoreOptions = {
    chainId: foundry.id,
    account: senderAccount,
    rpc: client as any,
    explorerApi: "",
    contracts: {} as any,
    circuits,
    snarkJs,
    services: {
      commitmentTreeSource,
      addressTreeSource,
      addressResolver,
      notesSource,
      contractSource: {} as any,
    }
  }

  const zkfi = new Core(coreOpt);

  // creating ethers signer using its wallet class
  const sepoliaProvider = new ethers.JsonRpcProvider(process.env.RPC_ETHEREUM_SEPOLIA);
  const envPrivateKey = process.env.SEPOLIA_TEST_PRIV_KEY;
  const privateKey = envPrivateKey.slice(2).padStart(64, '0');
  const wallet = new ethers.Wallet(privateKey);

  const signer = wallet.connect(sepoliaProvider);
  console.log("Creating nebra client");
  const upaInstanceDescriptor: UpaInstanceDescriptor = {
    "verifier": "0x3B946743DEB7B6C97F05B7a31B23562448047E3E",
    "deploymentBlockNumber": 6405136,
    "deploymentTx": "0xa8626318b76b71cd21cdfb93ef67c9571d94e01383e852a3eb6dc5dc6188808e",
    "chainId": "11155111"
  };
  const nebraClient: UpaClient = await zkfi.generateNebraClient(signer, upaInstanceDescriptor);

  zkfi.getRevokerData = async () => ({
    id: 0,
    revokerPublicKey,
    encryptionPublicKey,
    isActive: true,
  });

  // zkfi.getPaymasterFee = async () => BigInt(parseEther("0.002"));

  // bypassing fee calculation (in selected asset) call to Paymaster for testing purpose
  zkfi.getUserOpFee = async (options: TransactionOptions, feeAssetId: number, client: any): Promise<bigint> => {
    const requiredPrefundInETH = options.requiredPrefundEth;
    const ethInUSD: bigint = parseUnits("4000", 6);

    // assuming the fee asset is USDC, if not ETH (token1, testnetETH)
    // fixture token ids:
    // ETH = 65537
    // USDC = 65538
    // reentranceToken = 65539
    // testnetETH = 65540
    // testnetUSDC = 65541
    // any other tokens required for testing adaptors from 65542 and onwards..
    if (feeAssetId == 65538 || feeAssetId == 65541) {
      return ((requiredPrefundInETH * ethInUSD) / parseEther("1"));
    } else if (feeAssetId == 65537 || feeAssetId == 65540) {
      return requiredPrefundInETH;
    } else {
      throw new Error(`fixture::sdk.ts::Unsupported fee asset id: ${feeAssetId} by the test setup. Please use USDC (65538 or 65541) or ETH (65537 or 65540) as fee asset in the test cases.`);
    }
  }

  return {
    sdk: zkfi,
    nebraClient
  };
};

// 26250000000000n
// 431252250000000n
