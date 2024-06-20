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
    "15187339732644800751812193648350861431733040013104897934882869545575329240973"
  ),
  BigInt(
    "18224946718075372665314217959364704865149122115871220475141871484502637776562"
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
    explorerApi: "",
    contracts: {} as any,
    circuits,
    snarkJs,
    services: {
      treeSource,
      addressResolver,
      notesSource,
      contractSource: {} as any,
    },
  });

  zkfi.getEncryptionPublicKey = async () => encryptionPublicKey;
  zkfi.getFeeEstimate = async () => BigInt(parseEther("0.001"));

  return zkfi;
};
