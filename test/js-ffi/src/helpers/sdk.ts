//@ts-ignore
import * as snarkJs from "snarkjs";
import { createTestClient, http, keccak256, stringToBytes } from "viem";
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

const treeDepth = 24;
const zeroElement = Fp.from(keccak256(stringToBytes("zkFi"))).toHex();
const hashFunction = (a: any, b: any) => poseidonHash([a, b]);
export const tree = new MerkleTree(treeDepth, [], {
  zeroElement,
  hashFunction,
});

export const getSDKInstance = ({ account }: any) => {
  const client = createTestClient({
    chain: foundry,
    mode: "anvil",
    transport: http(),
  });

  const treeSource = new MockTreeSource(tree);
  const addressResolver = new MockAddressResolver();
  const notesSource = new MockNotesSource();

  const zkfi = new Core({
    chainId: foundry.id,
    account,
    rpc: client as any,
    contracts: {} as any,
    circuits,
    isTestnet: true,
    snarkJs,
    services: {
      treeSource,
      eventFetcher: {} as any,
      addressResolver,
      notesSource,
    },
  });

  return zkfi;
};
