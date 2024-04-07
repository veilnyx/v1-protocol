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
import { Fp, Fr, Point, poseidonHash } from "@zkfi-tech/babyjubjub";
import { circuits } from "./zk";
import { ShieldedAccount } from "@zkfi-tech/account";

const treeDepth = 32;
const zeroElement = Fp.from(keccak256(stringToBytes("zkFi"))).toHex();
const hashFunction = (a: any, b: any) => poseidonHash([a, b]);
export const tree = new MerkleTree(treeDepth, [], {
  zeroElement,
  hashFunction,
});
const account = ShieldedAccount.generate(
  Fr.from(keccak256(stringToBytes("sender"))).val
);
const encryptionPublicKey = Point.fromArray([
  BigInt(
    "18136749973959690676930643759397962821618865161533601684883289116728073483917"
  ),
  BigInt(
    "7818464758266392754559612367237682152094555123891341826265694881788827476134"
  ),
]);

export const getSDKInstance = () => {
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
    snarkJs,
    services: {
      treeSource,
      addressResolver,
      notesSource,
    },
  });

  zkfi.getEncryptionPublicKey = async () => encryptionPublicKey;

  return zkfi;
};
