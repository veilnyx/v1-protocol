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
import { Core, CoreOptions } from "@zkfi-tech/core";
import MerkleTree from "fixed-merkle-tree";
import { Fp, poseidonHash } from "@zkfi-tech/babyjubjub";
import { NebraClientAndCircuitIds } from "@zkfi-tech/zk-prover";
import { toBigInt } from "@zkfi-tech/utils";
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
  const nebraClientAndCircuitIds: NebraClientAndCircuitIds = await zkfi.createNebraClientAndGenerateCircuitIds(signer);
  const { nebraClient, circuitIds } = nebraClientAndCircuitIds;

  zkfi.getRevokerData = async () => ({
    id: 0,
    revokerPublicKey,
    encryptionPublicKey,
    isActive: true,
  });

  zkfi.getPaymasterFee = async () => BigInt(parseUnits("5", 6));

  return {
    sdk: zkfi,
    nebraClient,
    circuitIds
  };
};
