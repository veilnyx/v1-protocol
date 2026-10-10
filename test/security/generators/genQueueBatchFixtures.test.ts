/**
 * Generates the fixture used by test/security/QueueStableBatch.t.sol.
 * See test/security/generators/README.md for how to run the generators.
 *
 * A real Groth16 tree-update proof made with v1-circuits/artifacts/treeUpdate/keys.zkey. That key's
 * delta matches script/ceremony-manifest.json, and the proof verifies against the production
 * src/verifiers/VerifierTreeUpdate.sol. Check both again if the artifacts folder is rebuilt: the
 * committed DevVerifierTreeUpdate.sol belongs to an older dev key and will not verify this proof.
 *
 * The proof is for a PARTIAL batch: 3 leaves from the genesis tree, padded with 7 zero leaves
 * (batchSize 3, nZeroLeaves 7). The Solidity test queues those 3 leaves, queues more leaves
 * afterwards, and checks that the proof still verifies. LEAVES must match the constants in that test.
 */
import { describe, test, expect, jest } from '@jest/globals';
import { writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import * as snarkJs from 'snarkjs';
import { poseidonHash } from '@veilnyx-sdk/babyjubjub';
import { Prover } from '../src/prover';
import { zeroElement } from './helpers/services';
import { getCircuitPath } from './helpers/zk';

// @ts-ignore
globalThis.snarkjs = snarkJs;

const OUT = process.env.POC_OUT as string;
const CM_DEPTH = 25;
const QUEUE_SIZE = 10;
const LEAVES = [1111n, 2222n, 3333n];

const initialTree = () => {
  let z = BigInt(zeroElement);
  const subtrees: bigint[] = [];
  const zeros: bigint[] = [];
  for (let i = 0; i < CM_DEPTH; i++) {
    zeros.push(z);
    subtrees.push(z);
    z = poseidonHash([z, z]);
  }
  return { subtrees, zeros, root: z, nextLeafIndex: 0, depth: CM_DEPTH };
};

const write = (name: string, hex: string) => {
  mkdirSync(OUT, { recursive: true });
  writeFileSync(path.join(OUT, `${name}.txt`), hex);
  console.log(`wrote ${name}`);
};

describe('queue stable batch: partial tree-update proof', () => {
  jest.setTimeout(1800000);

  test('generate', async () => {
    const prover = new Prover({ circuits: { treeUpdate: getCircuitPath('treeUpdate') } } as any);
    const tu = await prover.proveTreeUpdate({
      lastTree: initialTree() as any,
      leaves: LEAVES,
      queueSize: QUEUE_SIZE,
      forceUpdate: true,
    } as any);
    expect((tu as any).batchSize ?? LEAVES.length).toBe(LEAVES.length);
    write('poc_tree_update_batch3', tu.encode());
  });
});
