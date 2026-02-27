const path = require("path");
import { writeFileSync } from "fs";
import { keccak256, stringToBytes } from "viem";
import { fp, poseidonHash } from "@labyrinthac/babyjubjub";
import { MerkleTreeState } from "@labyrinthac/zk-prover";
import { Core } from "@labyrinthac/core";
import { fixture } from "./fixture";

const dirFixtureData = path.resolve(__dirname, "../data");

export const genTreeUpdateData = async (sdk: Core) => {
  let initialTreeState: MerkleTreeState = getInitialTreeState();
  const treeUpdateData1 = await sdk.prover.proveTreeUpdate({
    lastTree: initialTreeState,
    leaves: fixture.leavesQueue1,
    batchSize: fixture.qmtBatchSize,
  });

  const treeUpdateData2 = await sdk.prover.proveTreeUpdate({
    lastTree: treeUpdateData1.newTree,
    leaves: fixture.leavesQueue2,
    batchSize: fixture.qmtBatchSize,
  });

  const encodedTreeUpdateData1 = treeUpdateData1.encode();
  const encodedTreeUpdateData2 = treeUpdateData2.encode();
  writeFileSync(
    `${dirFixtureData}/tree_update_data_1.txt`,
    encodedTreeUpdateData1
  );
  writeFileSync(
    `${dirFixtureData}/tree_update_data_2.txt`,
    encodedTreeUpdateData2
  );
};

export const genTreeUpdateDataWithPartialQueue = async (sdk: Core) => {
  let initialTreeState: MerkleTreeState = getInitialTreeState();

  // adding ZERO_LEAF to make it 10 leaves
  let leavesPartialQueue: bigint[] = [...fixture.leavesQueuePartial];

  const treeUpdateData1 = await sdk.prover.proveTreeUpdate({
    lastTree: initialTreeState,
    leaves: leavesPartialQueue,
    batchSize: fixture.qmtBatchSize,
    forceUpdate: true,
  });

  const treeUpdateData2 = await sdk.prover.proveTreeUpdate({
    lastTree: treeUpdateData1.newTree,
    leaves: fixture.leavesQueue2,
    batchSize: fixture.qmtBatchSize,
  });

  const encodedPartialTreeData = treeUpdateData1.encode();
  const encodedFullTreeData = treeUpdateData2.encode();

  writeFileSync(
    `${dirFixtureData}/tree_update_data_partial_queue.txt`,
    encodedPartialTreeData
  );
  writeFileSync(
    `${dirFixtureData}/tree_update_data_2.txt`,
    encodedFullTreeData
  );
};

export const getInitialTreeState = (): MerkleTreeState => {
  let z = fp.create(BigInt(keccak256(stringToBytes("zero"))));
  
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
