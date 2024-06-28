//@ts-ignore
import * as snarkJs from "snarkjs";
import {
  createTestClient,
  http,
  keccak256,
  parseEther,
  stringToBytes,
} from "viem";
import { foundry } from "viem/chains";
import { Core } from "@zkfi-tech/core";
import {
  MockAddressResolver,
  MockNotesSource,
  MockTreeSource,
} from "./services";
import MerkleTree from "fixed-merkle-tree";
import { Fp, poseidonHash } from "@zkfi-tech/babyjubjub";
import { circuits } from "./zk";
import { fixture } from "./fixture";

const {
  senderAccount,
  revokerPublicKey,
  encryptionPublicKey,
  addressTreeDepth,
  commitmentTreeDepth,
} = fixture;

const zeroElement = Fp.from(keccak256(stringToBytes("zkFi"))).toHex();
const hashFunction = (a: any, b: any) => poseidonHash([a, b]);

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
  console.log("addrRoot", addressTreeSource.root.toString());

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
