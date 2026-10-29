/**
 * Fixtures for test/security/RedeployForkSuite.t.sol: the redeploy's pool (this branch) on a
 * HyperEVM 999 fork, with the v2 transaction hash enabled.
 *
 * Real Groth16 proofs with the PRODUCTION ceremony keys (mainnet-circuits-8a65d25; the same
 * verifying keys as src/verifiers and the live 999 verifiers). The pool is deployed at a fixed
 * address (REDEPLOY_POOL below = RedeployForkSuite.POOL) because the v2 hash binds it.
 *
 * Every transaction is signed over `hashV2`, computed here from the exact ABI encoding the pool
 * receives (`ZTransaction.toSolidityInput`), so an accepted proof also proves this formula and
 * ShieldedTransactionLogic.hashV2 agree. Honest steps are proved; each attack is either a fully
 * consistent attacker transaction (proved; the pool must reject it) or a witness the circuit must
 * refuse (recorded as "circuit-rejected" in redeploy_results.json, no fixture written).
 *
 * Run (see README.md): POC_OUT=<v1-protocol>/test/fixtures/data PROD_CIRCUITS=<dir> \
 *   pnpm exec jest tests/genRedeployForkFixtures.test.ts --forceExit
 */
import { describe, test, jest } from '@jest/globals';
import { writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import { padHex, toHex, keccak256, toBytes, encodeAbiParameters, parseAbiParameters, Hex } from 'viem';
import MerkleTree from 'fixed-merkle-tree';
import * as snarkJs from 'snarkjs';
import { ShieldedAccount } from '@veilnyx-sdk/account';
import { poseidonHash } from '@veilnyx-sdk/babyjubjub';
import { Note, Transaction, createTransactionMemos } from '@veilnyx-sdk/transaction';
import { TransactionType } from '@veilnyx-sdk/shared-types';
import { Prover } from '../src/prover';
import { ZTransaction } from '../src/ztx';
import { hashEncryptedDataInputsSha256, hashEncryptedDataInputsPoseidon } from '../src/helpers';
import { revokerData } from './helpers/tx';
import { MockTreeSource, zeroElement } from './helpers/services';

// @ts-ignore
globalThis.snarkjs = snarkJs;

const P = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;
const OUT = process.env.POC_OUT as string;
const MC = process.env.PROD_CIRCUITS ?? '../../../mainnet-circuits-8a65d25';
const CHAIN_ID = 999;
/// address(uint160(uint256(keccak256("palliora.redeploy.fork.pool")))) — RedeployForkSuite.POOL
const REDEPLOY_POOL = ('0x' + keccak256(toBytes('palliora.redeploy.fork.pool')).slice(-40)) as Hex;
const OTHER_POOL = '0x000000000000000000000000000000000000dEaD' as Hex;
const TX_HASH_V2_TAG = keccak256(toBytes('Palliora.ShieldedTransaction.v2'));
const USDC = 65538; // WHYPE (65537) is added first, as on the live pool
const WHYPE = 65537;
const CM_DEPTH = 25;
const ADDR_DEPTH = 20;
const QUEUE_SIZE = 10;
// EOAs the fork test signs registrations with (vm.addr of 0xa11ce / 0xb0b / 0xbad0)
const EOA = {
  alice: '0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7',
  bob: '0x0376AAc07Ad725E01357B1725B5ceC61aE10473c',
  mallory: '0x21ce4F6a6EaC9B0E69e084Ce4D53e5Cf8Aa2F68F',
};
const u = (n: number) => BigInt(Math.round(n * 1e6));
const DUMMY_PROOF: any = { a: [0n, 0n], b: [[0n, 0n], [0n, 0n]], c: [0n, 0n] };

const cp = (name: string) => ({ zKey: `${MC}/${name}/keys.zkey`, wasm: `${MC}/${name}/circuit.wasm`, vKey: `${MC}/${name}/vKey.json` });
const circuits: any = {};
for (const c of ['transact21', 'transact22', 'transact23', 'transact42', 'transact44', 'transact82', 'transact84', 'register', 'treeUpdate'])
  circuits[c] = cp(c);

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

/// ShieldedTransactionLogic.hashV2, over the pool's view of the transaction.
const hashV2 = (z: ZTransaction, chainId: number, pool: Hex): bigint => {
  const s: any = z.toSolidityInput();
  const head = keccak256(
    encodeAbiParameters(parseAbiParameters('uint8, uint16, uint256, uint256, uint256, uint256'), [
      s.txType, s.revokerId, s.addressTreeRoot, s.commitmentTreeRoot, BigInt(s.feeData), s.refundAddress,
    ]),
  );
  const arrays = keccak256(
    encodeAbiParameters(parseAbiParameters('uint248[], uint256[], uint256[]'), [s.pubAssets, s.nullifiers, s.commitments]),
  );
  const memos = keccak256(
    encodeAbiParameters(parseAbiParameters('bytes, bytes, bytes, bytes'), [s.assetsMemo, s.keysMemo, s.notesMemo, s.targetData]),
  );
  return (
    BigInt(
      keccak256(
        encodeAbiParameters(parseAbiParameters('bytes32, uint256, address, bytes32, bytes32, bytes32'), [
          TX_HASH_V2_TAG, BigInt(chainId), pool, head, arrays, memos,
        ]),
      ),
    ) % P
  );
};

const results: Record<string, any> = {};
const write = (name: string, hex: string, meta: any = {}) => {
  mkdirSync(OUT, { recursive: true });
  writeFileSync(path.join(OUT, `redeploy_${name}.txt`), hex);
  results[name] = { ...(results[name] ?? {}), fixture: `redeploy_${name}`, ...meta };
  console.log(`wrote redeploy_${name}`);
};
const note = (name: string, meta: any) => {
  results[name] = { ...(results[name] ?? {}), ...meta };
  console.log(`[${name}] ${JSON.stringify(meta)}`);
};

let inProving = false;

type Ctx = { account: any; addressTree: MockTreeSource; commitmentTree: MockTreeSource };
type Signed = { z: ZTransaction; hash: bigint; signature: any };
type ProveOpts = {
  aliasNullifier?: boolean; // publish nullifier[0] as n + p
  aliasCommitment?: boolean; // publish commitment[0] as c + p
  hashMode?: 'v2' | 'legacy';
  chainId?: number;
  pool?: Hex;
  reuse?: { hash: bigint; signature: any }; // prove with someone else's hash + signature
};

/// The transaction as the SDK builds it (unsigned), plus the params/ctx used, so an attacker can
/// replace output notes and rebuild the memos consistently.
const build = (type: TransactionType, account: any, o: { assetIds: number[]; values: bigint[]; notes: Note[]; to: string; addrRoot: bigint; cmRoot: bigint }) => {
  const params: any = {
    addressTreeRoot: o.addrRoot,
    commitmentTreeRoot: o.cmRoot,
    type,
    assetIds: o.assetIds,
    values: o.values,
    feeAssetId: 0,
    feeValue: 0n,
    to: o.to,
  };
  const ctx: any = { chainId: CHAIN_ID, account, notes: o.notes, revokerData };
  const tx: any = new Transaction(params, ctx);
  return { tx, params, ctx };
};

/// Replace the output notes (attacker-chosen) and rebuild the memos the SDK way.
const withOutNotes = (b: any, outNotes: Note[], extraZ?: any) => {
  b.tx.outNotes = outNotes;
  const zAddresses = [b.ctx.account.shieldedAddress];
  if (extraZ) zAddresses.push(extraZ);
  b.tx.memos = createTransactionMemos({
    params: b.params,
    ctx: b.ctx,
    outNotes,
    refundAddress: b.tx.refundAddress,
    refundAddressBlinding: b.tx.refundAddressBlinding,
    zAddresses,
  } as any);
  return b;
};

/// Sign (v2 by default) and prove. The hash is computed from the transaction as published,
/// so aliased words are hashed raw, exactly as the pool sees them.
const prove = async (prover: Prover, tx: any, ctx: Ctx, signer: any, o: ProveOpts = {}): Promise<Signed> => {
  // The SDK refuses to replace a signature, so the placeholder (first pass only reads
  // nullifiers/commitments) and the real one are set on the backing field.
  tx._signature = { s: 0n, e: 0n };
  let inputs: any = Prover.createTxProofInputs(tx, ctx.account, ctx.addressTree, ctx.commitmentTree);
  const redN: bigint[] = inputs.inNullifiers.map((x: bigint) => BigInt(x) % P);
  const redC: bigint[] = inputs.outCommitments.map((x: bigint) => BigInt(x) % P);
  const rawN = redN.map((x, i) => (o.aliasNullifier && i === 0 ? x + P : x));
  const rawC = redC.map((x, i) => (o.aliasCommitment && i === 0 ? x + P : x));
  const mkZ = (hash: bigint, proof: any, betaUHF: bigint) =>
    new ZTransaction({
      chainId: tx.chainId, type: tx.type, hash, proof,
      addressTreeRoot: tx.addressTreeRoot, commitmentTreeRoot: tx.commitmentTreeRoot,
      pubAssetIds: tx.pubAssetIds, pubValues: tx.pubValues,
      nullifiers: rawN, commitments: rawC,
      feeAssetId: tx.feeAssetId, feeValue: tx.feeValue, paymaster: tx.paymaster,
      refundAddress: tx.refundAddress, target: tx.target, targetPayload: tx.targetPayload,
      memos: tx.memos, betaUHF,
    } as any);

  let h: bigint;
  if (o.reuse) {
    h = o.reuse.hash;
    tx._signature = o.reuse.signature;
  } else {
    h = o.hashMode === 'legacy' ? tx.hash() : hashV2(mkZ(0n, DUMMY_PROOF, 0n), o.chainId ?? CHAIN_ID, o.pool ?? REDEPLOY_POOL);
    tx._signature = await signer.sign(h);
  }

  inputs = Prover.createTxProofInputs(tx, ctx.account, ctx.addressTree, ctx.commitmentTree);
  inputs.hash = h;
  const pubIds = inputs.pubAssetIds.map((n: any) => BigInt(n));
  const alpha = hashEncryptedDataInputsSha256(pubIds, inputs.pubValues, rawN, rawC, inputs.encryptedDataEncryptionKeySeed, inputs.encryptedRefundData, inputs.encryptedNoteData);
  const beta = hashEncryptedDataInputsPoseidon(pubIds, inputs.pubValues, redN, redC, inputs.encryptedDataEncryptionKeySeed, inputs.encryptedRefundData, inputs.encryptedNoteData);
  const all = [...pubIds, ...inputs.pubValues, ...redN, ...redC, ...inputs.encryptedDataEncryptionKeySeed, ...inputs.encryptedRefundData, ...inputs.encryptedNoteData.flat()].map((x: any) => BigInt(x));
  let c = 1n;
  let gamma = 0n;
  for (const x of all) {
    gamma = (gamma + (x % P) * c) % P;
    c = (c * ((alpha + beta) % P)) % P;
  }
  inputs.alpha = alpha;
  inputs.beta = beta;
  inputs.gamma = gamma;
  inputs.inNullifiers = redN;
  inputs.outCommitments = redC;
  inProving = true;
  const { proof } = await prover.generateTransactionProof(inputs);
  return { z: mkZ(h, proof, beta), hash: h, signature: tx.signature };
};

/// An attack the circuit itself must refuse: record whether a proof could be made at all.
const expectCircuitRejects = async (name: string, f: () => Promise<Signed>) => {
  try {
    inProving = false;
    const s = await f();
    write(name, s.z.encode(), { stage: 'proof-produced', expect: 'pool-rejects' });
  } catch (e: any) {
    note(name, { stage: inProving ? 'circuit-rejected' : 'sdk-rejected-before-proving', error: String(e?.message ?? e).slice(0, 220) });
  }
};

const located = (n: any, leafIndex: number) =>
  new Note({ assetId: n.assetId, value: n.value, rootAddress: n.rootAddress, blinding: n.blinding, leafIndex, revoker: n.revoker });

describe('redeploy fork suite fixtures (production keys, v2 hash)', () => {
  jest.setTimeout(3600000);

  test('generate', async () => {
    console.log(`pool ${REDEPLOY_POOL} chain ${CHAIN_ID}`);
    const prover = new Prover({ circuits });
    const alice: any = ShieldedAccount.generate(11111111111111111111111111111111111111111111111111111111111111111111111111n);
    const bob: any = ShieldedAccount.generate(22222222222222222222222222222222222222222222222222222222222222222222222222n);
    const mallory: any = ShieldedAccount.generate(33333333333333333333333333333333333333333333333333333333333333333333333333n);

    const addrSrc = new MockTreeSource(new MerkleTree(ADDR_DEPTH, [], { hashFunction, zeroElement }));
    const cmSrc = new MockTreeSource(new MerkleTree(CM_DEPTH, [], { hashFunction, zeroElement }));
    const ctxOf = (account: any): Ctx => ({ account, addressTree: addrSrc, commitmentTree: cmSrc });

    // ---------- registrations (order = on-chain order). Proofs bind the EOA, not the domain. ----------
    for (const [name, acc] of [['alice', alice], ['bob', bob], ['mallory', mallory]] as const) {
      addrSrc.insert(acc.rootAddress);
      const reg = await prover.proveAddress(('0x' + '11'.repeat(65)) as any, acc, (EOA as any)[name]);
      write(`register_${name}`, reg.encode());
    }
    // a SECOND, different shielded account bound to Mallory's (already registered) EOA
    const mallory2: any = ShieldedAccount.generate(44444444444444444444444444444444444444444444444444444444444444444444444444n);
    write('register_mallory_second_account', (await prover.proveAddress(('0x' + '11'.repeat(65)) as any, mallory2, EOA.mallory as any)).encode());
    // the same key bound to Mallory's EOA again (duplicate registration)
    write('register_mallory_again', (await prover.proveAddress(('0x' + '11'.repeat(65)) as any, mallory, EOA.mallory as any)).encode());
    // Alice's key bound to Mallory's EOA (cannot be made without Alice's key; can it overwrite her binding?)
    write('register_alice_to_mallory_eoa', (await prover.proveAddress(('0x' + '11'.repeat(65)) as any, alice, EOA.mallory as any)).encode());

    const addrRoot = addrSrc.root as bigint;
    let tree: any = initialTree();
    const R0 = tree.root;

    // ---------- deposits ----------
    const dA = build(TransactionType.DEPOSIT, alice, { assetIds: [USDC], values: [u(100)], notes: [], to: alice.shieldedAddress.pack(), addrRoot, cmRoot: R0 });
    const dAZ = (await prove(prover, dA.tx, ctxOf(alice), alice)).z;
    write('deposit_alice_100', dAZ.encode());

    // tree update made while only Alice's deposit is queued: with #40 it stays valid after more
    // leaves are queued (it inserts exactly its batch)
    const tuStale = await prover.proveTreeUpdate({ lastTree: tree, leaves: dAZ.commitments, queueSize: QUEUE_SIZE, forceUpdate: true } as any);
    write('tree_update_early', tuStale.encode());

    const dB = build(TransactionType.DEPOSIT, bob, { assetIds: [USDC], values: [u(50)], notes: [], to: bob.shieldedAddress.pack(), addrRoot, cmRoot: R0 });
    const dBZ = (await prove(prover, dB.tx, ctxOf(bob), bob)).z;
    write('deposit_bob_50', dBZ.encode());

    // ...and the follow-up that inserts Bob's leaves on top of it (ends at the same root R1)
    const tuAfterEarly = await prover.proveTreeUpdate({ lastTree: (tuStale as any).newTree, leaves: dBZ.commitments, queueSize: QUEUE_SIZE, forceUpdate: true } as any);
    write('tree_update_after_early', tuAfterEarly.encode());

    // FEE ABUSE: deposit that claims a paymaster fee (fee-credit mint, 2026-09 audit)
    {
      const b = build(TransactionType.DEPOSIT, mallory, { assetIds: [USDC], values: [u(5)], notes: [], to: mallory.shieldedAddress.pack(), addrRoot, cmRoot: R0 });
      b.tx.paymaster = EOA.mallory;
      b.tx.feeAssetId = USDC;
      b.tx.feeValue = u(200);
      write('fee_mint_deposit', (await prove(prover, b.tx, ctxOf(mallory), mallory)).z.encode());
    }
    // ALIASED commitment deposit (c + p): froze the tree before the 2026-09 fix
    {
      const b = build(TransactionType.DEPOSIT, mallory, { assetIds: [USDC], values: [u(5)], notes: [], to: mallory.shieldedAddress.pack(), addrRoot, cmRoot: R0 });
      write('deposit_aliased_commitment', (await prove(prover, b.tx, ctxOf(mallory), mallory, { aliasCommitment: true })).z.encode());
    }

    // honest tree update over both deposits
    const queued1 = [...dAZ.commitments, ...dBZ.commitments];
    const tu1 = await prover.proveTreeUpdate({ lastTree: tree, leaves: queued1, queueSize: QUEUE_SIZE, forceUpdate: true } as any);
    write('tree_update_1', tu1.encode());
    tree = (tu1 as any).newTree;
    queued1.forEach((c: bigint) => cmSrc.insert(c));
    const R1 = cmSrc.root as bigint;
    if ((tuAfterEarly as any).newTree.root !== tree.root) throw new Error('early + after_early must end at R1');

    const idxOf = (c: bigint) => cmSrc.indexOf(c);
    const aliceNote100 = located(dA.tx.outNotes.find((n: any) => n.value === u(100)), idxOf(dAZ.commitments[dA.tx.outNotes.findIndex((n: any) => n.value === u(100))]));
    const bobNote50 = located(dB.tx.outNotes.find((n: any) => n.value === u(50)), idxOf(dBZ.commitments[dB.tx.outNotes.findIndex((n: any) => n.value === u(50))]));

    // ---------- Alice withdraws 40 (honest, v2) + the same spend signed other ways ----------
    const withdrawA40 = () => build(TransactionType.WITHDRAW, alice, { assetIds: [USDC], values: [u(40)], notes: [aliceNote100], to: EOA.alice, addrRoot, cmRoot: R1 });
    const wA = withdrawA40();
    const wAS = await prove(prover, wA.tx, ctxOf(alice), alice);
    const wAZ = wAS.z;
    write('withdraw_alice_40', wAZ.encode());

    write('withdraw_alice_40_legacy_hash', (await prove(prover, withdrawA40().tx, ctxOf(alice), alice, { hashMode: 'legacy' })).z.encode());
    write('withdraw_alice_40_other_pool', (await prove(prover, withdrawA40().tx, ctxOf(alice), alice, { pool: OTHER_POOL })).z.encode());
    write('withdraw_alice_40_other_chain', (await prove(prover, withdrawA40().tx, ctxOf(alice), alice, { chainId: 1 })).z.encode());

    // L-2: whoever holds Alice's viewing key and note openings, plus ONE signature from her, re-proves
    // the same spend with the change sent to Mallory. The proof is valid for the hash Alice signed;
    // under v2 that hash covers the outputs, so the pool computes a different hash and rejects it.
    {
      const b: any = withdrawA40();
      const outs = b.tx.outNotes.map((n: any) =>
        n.value === u(60) && BigInt(n.rootAddress) === BigInt(alice.rootAddress)
          ? new Note({ assetId: n.assetId, value: n.value, rootAddress: mallory.rootAddress, blinding: n.blinding, leafIndex: -1, revoker: n.revoker } as any)
          : n,
      );
      withOutNotes(b, outs, mallory.shieldedAddress);
      const s = await prove(prover, b.tx, ctxOf(alice), alice, { reuse: { hash: wAS.hash, signature: wAS.signature } });
      write('l2_reprove_change_to_mallory', s.z.encode(), { stage: 'proof-produced', expect: 'pool-rejects (hash mismatch)' });
    }

    const wA2 = build(TransactionType.WITHDRAW, alice, { assetIds: [USDC], values: [u(10)], notes: [aliceNote100], to: EOA.alice, addrRoot, cmRoot: R1 });
    write('double_spend_new_proof', (await prove(prover, wA2.tx, ctxOf(alice), alice)).z.encode());
    write('double_spend_aliased_nullifier', (await prove(prover, withdrawA40().tx, ctxOf(alice), alice, { aliasNullifier: true })).z.encode());

    // Mallory spends Alice's note with her own keys (ownership) — circuit must refuse
    await expectCircuitRejects('steal_alice_note_with_mallory_key', async () => {
      const b = build(TransactionType.WITHDRAW, mallory, { assetIds: [USDC], values: [u(100)], notes: [aliceNote100], to: EOA.mallory, addrRoot, cmRoot: R1 });
      return prove(prover, b.tx, ctxOf(mallory), mallory);
    });
    // Mallory forges a note at Alice's leaf position with HER root address (phantom ownership).
    // The SDK refuses a note that is not in the tree, so point the witness at Alice's real leaf.
    await expectCircuitRejects('phantom_note_mallory_owner', async () => {
      const fake = new Note({ assetId: USDC, value: u(100), rootAddress: mallory.rootAddress, blinding: aliceNote100.blinding, leafIndex: aliceNote100.leafIndex, revoker: aliceNote100.revoker } as any);
      const b = build(TransactionType.WITHDRAW, mallory, { assetIds: [USDC], values: [u(100)], notes: [fake], to: EOA.mallory, addrRoot, cmRoot: R1 });
      const lying: any = Object.create(cmSrc);
      lying.indexOf = (c: bigint) => (BigInt(c) === BigInt(fake.commitment) ? aliceNote100.leafIndex : cmSrc.indexOf(c));
      return prove(prover, b.tx, { account: mallory, addressTree: addrSrc, commitmentTree: lying }, mallory);
    });

    const tu2 = await prover.proveTreeUpdate({ lastTree: tree, leaves: wAZ.commitments, queueSize: QUEUE_SIZE, forceUpdate: true } as any);
    write('tree_update_2', tu2.encode());
    tree = (tu2 as any).newTree;
    wAZ.commitments.forEach((c: bigint) => cmSrc.insert(c));
    const R2 = cmSrc.root as bigint;

    // ---------- Bob transfers 20 to Alice (honest) ----------
    const tB = build(TransactionType.TRANSFER, bob, { assetIds: [USDC], values: [u(20)], notes: [bobNote50], to: alice.shieldedAddress.pack(), addrRoot, cmRoot: R2 });
    const tBZ = (await prove(prover, tB.tx, ctxOf(bob), bob)).z;
    write('transfer_bob_to_alice_20', tBZ.encode());
    const tu3 = await prover.proveTreeUpdate({ lastTree: tree, leaves: tBZ.commitments, queueSize: QUEUE_SIZE, forceUpdate: true } as any);
    write('tree_update_3', tu3.encode());
    tree = (tu3 as any).newTree;
    tBZ.commitments.forEach((c: bigint) => cmSrc.insert(c));
    const R3 = cmSrc.root as bigint;

    const pick = (b: any, z: any, owner: any, value: bigint) => {
      const i = b.tx.outNotes.findIndex((n: any) => n.value === value && BigInt(n.rootAddress) === BigInt(owner.rootAddress));
      if (i < 0) throw new Error(`no output of ${value} for owner`);
      return located(b.tx.outNotes[i], idxOf(z.commitments[i]));
    };
    const aliceGot20 = pick(tB, tBZ, alice, u(20));
    const bobChange30 = pick(tB, tBZ, bob, u(30));

    // The SENDER knows every field of the note he created for Alice: can Bob spend it back?
    await expectCircuitRejects('sender_steals_sent_note', async () => {
      const b = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(20)], notes: [aliceGot20], to: EOA.bob, addrRoot, cmRoot: R3 });
      return prove(prover, b.tx, ctxOf(bob), bob);
    });
    // ...and a third party who learned the opening
    await expectCircuitRejects('third_party_steals_received_note', async () => {
      const b = build(TransactionType.WITHDRAW, mallory, { assetIds: [USDC], values: [u(20)], notes: [aliceGot20], to: EOA.mallory, addrRoot, cmRoot: R3 });
      return prove(prover, b.tx, ctxOf(mallory), mallory);
    });
    // the SAME note as both inputs of one transaction (withdraw 60 from a 30 note)
    await expectCircuitRejects('same_note_twice_in_one_tx', async () => {
      const b = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(60)], notes: [bobChange30, located(bobChange30, bobChange30.leafIndex)], to: EOA.bob, addrRoot, cmRoot: R3 });
      return prove(prover, b.tx, ctxOf(bob), bob);
    });
    // VALUE CREATION: withdraw 10 from the 30 note but keep a 1000 change note
    await expectCircuitRejects('inflate_change_note', async () => {
      const b: any = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: EOA.bob, addrRoot, cmRoot: R3 });
      const outs = b.tx.outNotes.map((n: any) =>
        n.value === u(20) ? new Note({ assetId: n.assetId, value: u(1000), rootAddress: n.rootAddress, blinding: n.blinding, leafIndex: -1, revoker: n.revoker } as any) : n,
      );
      withOutNotes(b, outs);
      return prove(prover, b.tx, ctxOf(bob), bob);
    });
    // FIELD WRAPAROUND: change split into (p - 100) and (120): sums to 20 mod p
    await expectCircuitRejects('field_wraparound_outputs', async () => {
      const b: any = build(TransactionType.TRANSFER, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: alice.shieldedAddress.pack(), addrRoot, cmRoot: R3 });
      const outs = b.tx.outNotes.map((n: any) => {
        const isAlice = BigInt(n.rootAddress) === BigInt(alice.rootAddress);
        const v = isAlice ? P - u(100) : n.value === u(20) ? u(120) : n.value;
        const out: any = new Note({ assetId: n.assetId, value: 1n, rootAddress: n.rootAddress, blinding: n.blinding, leafIndex: -1, revoker: n.revoker } as any);
        Object.defineProperty(out, 'value', { value: v, writable: true });
        return out;
      });
      withOutNotes(b, outs, alice.shieldedAddress);
      return prove(prover, b.tx, ctxOf(bob), bob);
    });
    // ASSET CONFUSION: spend a USDC note, output a WHYPE note of the same value
    await expectCircuitRejects('asset_confusion_output', async () => {
      const b: any = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: EOA.bob, addrRoot, cmRoot: R3 });
      const outs = b.tx.outNotes.map((n: any) =>
        n.value === u(20) ? new Note({ assetId: WHYPE, value: n.value, rootAddress: n.rootAddress, blinding: n.blinding, leafIndex: -1, revoker: n.revoker } as any) : n,
      );
      withOutNotes(b, outs);
      return prove(prover, b.tx, ctxOf(bob), bob);
    });
    // C-2 REGRESSION (2026-07 audit): all-dummy inputs and outputs, yet a 10 USDC public withdraw
    await expectCircuitRejects('c2_withdraw_from_dummies', async () => {
      const b: any = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: EOA.bob, addrRoot, cmRoot: R3 });
      const dummy = () => Note.dummy(bob.shieldedAddress, revokerData.revokerPublicKey as any);
      b.tx.inNotes = b.tx.inNotes.map(() => dummy());
      withOutNotes(b, b.tx.outNotes.map(() => dummy()));
      return prove(prover, b.tx, ctxOf(bob), bob);
    });

    // L-1 (circuit, next ceremony): an input with value p - assetId zeroes the Merkle-check enable
    // flag. It counts as -assetId in the balance, so it can only destroy value. Expected: proof
    // produced, pool accepts, Bob's change note is 65538 units smaller.
    {
      const b: any = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: EOA.bob, addrRoot, cmRoot: R3 });
      const fake: any = new Note({ assetId: USDC, value: 1n, rootAddress: bob.rootAddress, blinding: 777n, leafIndex: 0, revoker: bobChange30.revoker } as any);
      Object.defineProperty(fake, 'value', { value: P - BigInt(USDC), writable: true });
      fake.isDummy = () => false;
      b.tx.inNotes = [bobChange30, fake];
      const outs = b.tx.outNotes.map((n: any) =>
        n.value === u(20) ? new Note({ assetId: n.assetId, value: u(20) - BigInt(USDC), rootAddress: n.rootAddress, blinding: n.blinding, leafIndex: -1, revoker: n.revoker } as any) : n,
      );
      withOutNotes(b, outs);
      const lying: any = Object.create(cmSrc);
      lying.indexOf = (c: bigint) => (BigInt(c) === BigInt(fake.commitment) ? 0 : cmSrc.indexOf(c));
      try {
        inProving = false;
        const s = await prove(prover, b.tx, { account: bob, addressTree: addrSrc, commitmentTree: lying }, bob);
        write('l1_fake_negative_input', s.z.encode(), { stage: 'proof-produced', expect: 'pool-accepts-value-destroyed' });
      } catch (e: any) {
        note('l1_fake_negative_input', { stage: inProving ? 'circuit-rejected' : 'sdk-rejected-before-proving', error: String(e?.message ?? e).slice(0, 220) });
      }
    }

    // honest spend of Bob's change, used by the fee tests
    const wB = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: EOA.bob, addrRoot, cmRoot: R3 });
    write('withdraw_bob_10', (await prove(prover, wB.tx, ctxOf(bob), bob)).z.encode());

    // FEE: withdraw advertising a fee in a DIFFERENT asset than the one paid out
    {
      const b = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: EOA.bob, addrRoot, cmRoot: R3 });
      b.tx.paymaster = EOA.mallory;
      b.tx.feeAssetId = WHYPE;
      b.tx.feeValue = 10n ** 18n;
      write('fee_mismatched_asset', (await prove(prover, b.tx, ctxOf(bob), bob)).z.encode());
    }
    // FEE: fee larger than the public value withdrawn
    {
      const b = build(TransactionType.WITHDRAW, bob, { assetIds: [USDC], values: [u(10)], notes: [bobChange30], to: EOA.bob, addrRoot, cmRoot: R3 });
      b.tx.paymaster = EOA.mallory;
      b.tx.feeAssetId = USDC;
      b.tx.feeValue = u(25);
      write('fee_exceeds_value', (await prove(prover, b.tx, ctxOf(bob), bob)).z.encode());
    }

    writeFileSync(path.join(OUT, 'redeploy_results.json'), JSON.stringify(results, null, 2));
  });
});
