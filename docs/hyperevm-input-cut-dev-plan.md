# HyperEVM public-input cut: development plan

Branch `feat/hyperevm-input-cut` in v1-circuits, v1-protocol, v1-sdk and veilnyx-hyperliquid.
Restore point: tag `checkpoint/pre-input-cut-2026-11-12` (v1-circuits 0c7ea94, v1-protocol 09ea1cb = live 999 impl 0x7b72b77f, veilnyx-hyperliquid main 3cf2c33 and `-staging` 75fa56b).

Goal: stay on 3M-gas small blocks after the HyperEVM precompile repricing at block 50,988,232 (BN254 10x, ecrecover 5x) by cutting Groth16 public inputs. Each public input costs ~61,500 gas at the new prices; the 4-pair pairing (~1.81M) is fixed.

Nothing goes to testnet until every local gate below passes and the owner approves.

## 1. Specification

All hashes reduce mod p (BN254 scalar field), contract and circuit identically. Every value that enters a hash must be a canonical field element (< p); the contract rejects non-canonical words, the circuit uses `Num2Bits_strict`.

### 1.1 Transact (all 7 shapes): 12 -> 3 public inputs (alpha, beta, gamma)

The 9 plain values become private and are prepended to the UHF data list D, in this order:

| # | value | source in contract |
|---|---|---|
| 0 | addressTreeRoot | calldata, checked against known roots |
| 1 | commitmentTreeRoot | calldata, checked against known roots |
| 2 | hash | computed by contract (`hash(stx)` / v2) |
| 3 | pubFlow | 0 for DEPOSIT, else 1 |
| 4, 5 | outRevokerPublicKey x, y | revoker registry (storage) |
| 6 | refundAddress | calldata |
| 7, 8 | keySeedEncryptionPublicKey x, y | revoker registry (storage) |

followed by the existing list (pubAssetIds, pubValues, nullifiers, commitments, DEK seed[3], refund[4], notes[nOuts x 4]).

- alpha = sha256 chain over D computed on-chain (header chunk first, then existing chunks).
- beta = chained Poseidon(2) over D, enforced in-circuit, supplied in calldata (`betaUHF`).
- gamma = sum D_i (alpha + beta)^i, computed on-chain, enforced in-circuit.

Soundness rule: every value must be in BOTH the alpha chain and the beta chain. If a value were only in alpha, the prover could fix the chain data, then solve gamma for that value linearly, because r = alpha + beta would not depend on it.

### 1.2 Register: 6 -> 1 public input

`inputsHash = uint256(sha256(shieldedAddress[160 bytes] || uint256(publicAddress))) % p`, i.e. sha256 over (rootAddress, signPK.x, signPK.y, viewPK.x, viewPK.y, publicAddress). sha256 is not repriced (~1k gas). Poseidon on-chain would add ~100k and register is the tightest transaction (est. ~2.86M).

### 1.3 Tree update: 64 -> 1 public input (frontier design)

`inputsHash = uint256(sha256(leafIndex || leaves[10] || lastRoot || newRoot || nZeroLeaves)) % p` (14 words).

`lastSubtrees` and `newSubtrees` become private. The circuit binds `lastSubtrees` to `lastRoot` by recomputing the root of the frontier at `leafIndex` (one extra 25-level path). The contract keeps supplying `lastRoot` and `leafIndex` from storage, and stops storing `levelSubtrees`. Provers (keeper, browser Settle) derive the frontier from the commitment leaves they already sync.

Measured (circom 2.2.3, non-linear constraints):

| variant | constraints | ptau |
|---|---|---|
| today (64 public inputs) | 61,808 | 2^17 |
| sha256 over all 64 values | 1,094,057 | 2^21 |
| **frontier design (14 values)** | **316,406** | **2^19** |

Hashing all 64 would make browser and keeper proofs about 18x heavier, so the frontier design is used.

### 1.4 Same ceremony, same branch

- November audit Low: `MerkleProof.enabled = 1 - IsZero(assetId) * IsZero(value)` plus `LimitRange(224)` on `inValues`.
- Remove dead circuits `anonymityScore` and `linkTx` (and the unreferenced `VerifierAnonymityScore.sol`).

## 2. Work items

### Circuits (v1-circuits)
1. Transact header fold + negative test per folded value (change one value only -> witness fails or gamma mismatch).
2. Audit Low fix + test (the fakeNote PoC must fail).
3. Register sha256 binding + tests.
4. Tree-update frontier design + tests (wrong subtree at a bit=1 level must fail; bit=0 levels are don't-cares by construction).
5. Remove dead circuits.
6. Confirm every circuit fits its ptau (transact84 under 2^18 wires).
7. Dev keys (single contribution, NOT the ceremony) + Solidity verifiers.

### Contracts (v1-protocol)
1. `ShieldedTransactionLogic`: header chunk into alpha and gamma; verifier input = proof || alpha || beta || gamma.
2. `ShieldedAddressLogic`: register inputsHash.
3. `QueuedMerkleTreeLogic`: tree inputsHash, stop writing `levelSubtrees`; `TreeUpdateData` loses `newLevelSubtrees` (ABI change).
4. New `Verifier` router (public-input constants are compile-time: 3 / 1 / 1) + new verifiers.
5. Pool reinitializer (`reinitializer(3)`) sets the new router in `verifier` and `_commitmentTree.verifier`; storage layout append-only (checked against live impl).
6. Update mocks/tests that hardcode 12/6/64 (`AuditTrailingCalldata`, `AuditRegisterBinding`, `DevVerifier*`, `ceremony-manifest.json`).

### SDK (v1-sdk, from `feat/hyperliquid-unified`)
1. `zk-prover`: `createTxProofInputs` / `helpers.ts` UHF with the header; `ZTransaction.pubSignals()` -> 3; register and tree-update inputs; frontier derivation for tree update.
2. `core.proveTreeUpdate`: frontier from leaves, not `getCommitmentTreeState`.
3. Rebuild and copy into `veilnyx-hyperliquid/interface/vendor` (used by both app and keeper).

### Apps (veilnyx-hyperliquid)
Relayer `pool-abi.mjs` struct, `REGISTER_GAS`, `maxTxGas`; keeper `tree.mjs`; app ABI + gas limits; circuits served at the same paths (cache-busting needed).

## 3. Local test gates (anvil)

anvil prices precompiles like Ethereum, so functional tests run on anvil and gas at HyperEVM prices is computed separately: precompile call counts from traces x (new - old price), cross-checked with `eth_estimateGas` against HyperEVM where possible.

1. Circuit suite green (72 existing + new negatives).
2. Forge suite green with fixtures regenerated from the new dev keys (fixture scripts need the Nebra import removed first), plus the 25-attack fork suite against the new code.
3. Fresh anvil deploy: register, deposit, settle (keeper path and SDK path), transfer, withdraw, adaptor call.
4. Upgrade rehearsal on an anvil fork of 999: deposit with the CURRENT circuits, upgrade (new impl + router via impersonated owner), settle the queue with the new tree-update proof, then spend the pre-upgrade note with the new transact circuit. This proves no migration is needed.
5. Gas report at HyperEVM prices; target: every type < 3M with margin (est. transact ~2.4M, register ~2.86M, settle ~2.1M).

Only then: testnet 998 deploy with dev keys, owner approval first.
