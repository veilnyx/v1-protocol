const path = require("path");
import { writeFileSync } from "fs";
import { keccak256, stringToBytes } from "viem";
import { Fp, poseidonHash } from "@zkfi-tech/babyjubjub";
import { MerkleTreeState } from "@zkfi-tech/zk-prover";
import { Core } from "@zkfi-tech/core";
import { fixture } from "./fixture";

const dirFixtureData = path.resolve(__dirname, "../data");

export const genTreeUpdateData = async (sdk: Core) => {
  let initialTreeState: MerkleTreeState = getInitialTreeState();
  const treeUpdateData1 = await sdk.prover.proveTreeUpdate({
    lastTree: initialTreeState,
    leaves: fixture.leavesQueue1,
  });

  const treeUpdateData2 = await sdk.prover.proveTreeUpdate({
    lastTree: treeUpdateData1.newTree,
    leaves: fixture.leavesQueue2,
  });

  const encoded1 = treeUpdateData1.encode();
  const encoded2 = treeUpdateData2.encode();
  writeFileSync(`${dirFixtureData}/tree_update_data_1.txt`, encoded1);
  writeFileSync(`${dirFixtureData}/tree_update_data_2.txt`, encoded2);
};

export const genTreeUpdateDataWithPartialQueue = async (sdk: Core) => {
  let initialTreeState: MerkleTreeState = getInitialTreeState();

  // adding ZERO_LEAF to make it 10 leaves
  let leavesQueue: bigint[] = fixture.leavesQueuePartial;
  leavesQueue[8] = BigInt(fixture.zeroLeaf);
  leavesQueue[9] = BigInt(fixture.zeroLeaf);

  const treeUpdateData = await sdk.prover.proveTreeUpdate({
    lastTree: initialTreeState,
    leaves: leavesQueue,
  });

  const encoded = treeUpdateData.encode();
  writeFileSync(
    `${dirFixtureData}/tree_update_data_partial_queue.txt`,
    encoded
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
    subtrees: lastSubtree,
    zeros,
  };
};
