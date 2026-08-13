const path = require("path");
import { readFileSync, writeFileSync } from "fs";
import { Hex } from "viem";
import { Core } from "@veilnyx-sdk/core";
import { ZTransaction } from "@veilnyx-sdk/zk-prover";
import { fixture } from "./fixture";
import { getInitialTreeState } from "./genTreeUpdateData";

const dirFixtureData = path.resolve(__dirname, "../data");

/**
 * Proves the commitment tree update for exactly the leaves `deposit_pre_tx` queues.
 *
 * The existing tree_update_data_* fixtures prove insertion of `fixture.leavesQueue1`,
 * an arbitrary set from config, so they do not match the tree state a real deposit
 * produces. Submitting them after a deposit advances the tree to a root the pool has
 * never held, and the following withdrawal reverts with UnknownCommitmentTreeRoot.
 *
 * The end-to-end script needs a proof over the deposit's own commitments, which is
 * what this generates. Run it after genTestDeposits so it reads the current fixture.
 */
export const genHyperEvmTreeUpdate = async (sdk: Core) => {
  const encoded = readFileSync(
    `${dirFixtureData}/deposit_pre_tx.txt`,
    "utf8"
  ).trim() as Hex;

  // decode returns an ABI-decoded struct that TypeScript cannot type statically
  const ztx = ZTransaction.decode(encoded) as any;
  const leaves = ztx.commitments.map((c: any) => BigInt(c));

  console.log(
    `proving tree update over ${leaves.length} commitment(s) from deposit_pre_tx...`
  );

  // A deposit queues fewer leaves than queueSize, so this is the partial-queue
  // case. forceUpdate lets the prover pad to queueSize with ZERO_LEAF and set
  // nZeroLeaves accordingly, rather than requiring a full batch.
  const treeUpdate = await sdk.prover.proveTreeUpdate({
    lastTree: getInitialTreeState(),
    leaves,
    queueSize: fixture.qmtQueueSize,
    forceUpdate: true,
  });

  writeFileSync(
    `${dirFixtureData}/tree_update_deposit_pre_tx.txt`,
    treeUpdate.encode()
  );

  console.log("wrote tree_update_deposit_pre_tx.txt");
};
