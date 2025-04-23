//@ts-ignore
import * as snarkJs from "snarkjs";
import * as ethers from "ethers";
import dotenv from 'dotenv';
import path from 'path';
import {
  createTestClient,
  http,
  keccak256,
  padHex,
  parseEther,
  parseUnits,
  stringToBytes,
  toHex,
} from "viem";
import { foundry } from "viem/chains";
import { Core, CoreOptions } from "@labyrinthac/core";
import MerkleTree from "fixed-merkle-tree";
import { Fp, poseidonHash } from "@labyrinthac/babyjubjub";
import { UpaClient, UpaInstanceDescriptor } from "@nebrazkp/upa/sdk";
import { toBigInt } from "@labyrinthac/utils";
import {
  MockAddressResolver,
  MockNotesSource,
  MockTreeSource,
} from "./mockServices";
import { circuits } from "./zk";
import { fixture } from "./fixture";

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

const zeroElement = Fp.from(BigInt(keccak256(stringToBytes("zero")))).toHex();
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

  zkfi.getPaymasterFee = async () => BigInt(parseEther("0.002"));

  return {
    sdk: zkfi,
    nebraClient
  };
};
