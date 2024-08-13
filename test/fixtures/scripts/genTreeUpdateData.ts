const path = require("path");
import { writeFileSync } from "fs";
import { keccak256, stringToBytes } from "viem";
import { Fp, poseidonHash } from "@zkfi-tech/babyjubjub";
import { fixture } from "./fixture";
import { MerkleTreeState } from "@zkfi-tech/zk-prover";
import { getSDKInstance } from "./sdk";
import { Core } from "@zkfi-tech/core";

const dirFixtureData = path.resolve(__dirname, "../data");

export const genTreeUpdateData = async (sdk: Core) => {
  let initialTreeState: MerkleTreeState = getInitialTreeState();
  const subtreeUpdateData = await sdk.prover.proveSubtreeUpdate({
    lastTree: initialTreeState,
    leaves: fixture.leavesQueue,
  });
  const subtreeUpdateDataEncoded = subtreeUpdateData.encode();
  writeFileSync(
    `${dirFixtureData}/subtreeUpdateData.txt`,
    subtreeUpdateDataEncoded
  );
};

export const getInitialTreeState = (): MerkleTreeState => {
  let z = Fp.from(keccak256(stringToBytes("zero"))).val;
  const lastSubtree: bigint[] = [];
  const zeros: bigint[] = [];
  const treeDepth: number = fixture.commitmentTreeDepth;

  for (let i = 0; i < treeDepth; i++) {
    zeros.push(z);
    lastSubtree.push(z);
    z = poseidonHash([z, z]);
  }
  const root = z;

  return {
    depth: treeDepth,
    root,
    nextLeafIndex: 0,
    subtree: lastSubtree,
    zeros,
  };
};
