//@ts-ignore
import * as snarkJs from "snarkjs";
import {
  createTestClient,
  http,
  keccak256,
  padHex,
  parseEther,
  stringToBytes,
  toHex,
} from "viem";
import { foundry } from "viem/chains";
import { Core } from "@labyrinthac/core";
import MerkleTree from "fixed-merkle-tree";
import { Fp, poseidonHash } from "@labyrinthac/babyjubjub";
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

export const getSDKInstance = () => {
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

  const zkfi = new Core({
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
    },
  });

  zkfi.getRevokerData = async () => ({
    id: 0,
    revokerPublicKey,
    encryptionPublicKey,
    isActive: true,
  });

  zkfi.getPaymasterFee = async () => BigInt(parseEther("0.001"));

  return zkfi;
};
