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

const addressTreeDepth = 20;
const commitmentTreeDepth = 25;
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

const account = ShieldedAccount.generate(
  Fr.from(keccak256(stringToBytes("sender"))).val
);

const revokerPublicKey = Point.fromArray([
  BigInt(
    "8116072818876777666029027213729376705234613448128995613697283149497235402123"
  ),
  BigInt(
    "4598772416842731049226007701899382609184728232075557894618791492264594188716"
  ),
]);

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

  const commitmentTreeSource = new MockTreeSource(commitmentTree);
  const addressTreeSource = new MockTreeSource(addressTree);
  const addressResolver = new MockAddressResolver();
  const notesSource = new MockNotesSource();

  addressTreeSource.insert(account.rootAddress);

  const zkfi = new Core({
    chainId: foundry.id,
    account,
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

  zkfi.getCompliancePublicKeys = async () => ({
    id: 0,
    revokerPublicKey,
    encryptionPublicKey,
    isActive: true,
  });

  zkfi.getFeeEstimate = async () => BigInt(parseEther("0.001"));

  return zkfi;
};
