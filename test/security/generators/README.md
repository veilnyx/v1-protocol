# Security regression fixtures: generators

Every `poc_*` fixture in `test/fixtures/data/` used by `test/security/*.t.sol` is a real Groth16
proof. The two Jest tests here build the transactions with the Veilnyx SDK, prove them, and write
the encoded calldata that `_loadShieldedTransaction` and `_loadTreeUpdateData` read.
Regenerating the fixtures reproduces the whole chain: tx building → proving → on-chain execution.

| Generator | Fixtures | Keys | Used by |
|---|---|---|---|
| `genFeeFixtures.test.ts` | `poc_fee_deposit`, `poc_fee_withdraw0`, `poc_fee_transfer_nopub` | **production** (`v1-interface/public/mainnet-circuits`; vKeys = `src/verifiers` at `72cb8de`) | `FeeBacking.t.sol`, `PaymasterFeeBacking.t.sol` |
| `genFieldAliasFixtures.test.ts` | `poc_register`, `poc_deposit`, `poc_deposit_aliased_cm`, `poc_deposit_victim_r0`, `poc_tree_update`, `poc_tree_update_dos`, `poc_tree_update_noop`, `poc_withdraw`, `poc_withdraw_aliased` | **dev** (`v1-circuits/artifacts`, v1-circuits `7270065`) | `FieldCanonicality.t.sol`, `DepositScreening.t.sol` |
| `genQueueBatchFixtures.test.ts` | `poc_tree_update_batch3` | `v1-circuits/artifacts/treeUpdate` (matches the production ceremony delta, see the generator header) | `QueueStableBatch.t.sol` |

## How the attack transactions are built

**Fee fixtures.** Each transaction is built through the SDK with `feeAssetId: 0`, so
`getPublicAssets` folds no fee into `pubAssets`. Then `paymaster`, `feeAssetId` and `feeValue`
are set on the `Transaction` object before it is signed and proved.

The proof is honest. `ZeroSumFungible` balances the notes against `pubAssets` as submitted,
and `feeData` only enters the signed hash. The SDK would never build these transactions,
but the contract must not rely on the SDK. Before the fix, the pool credited `feeValue` anyway.

**Aliased fixtures.** `proveRaw` proves the transaction over the field-reduced
nullifiers and commitments, which is what the circuit sees. It then publishes them raw, as `x + p`.
`alpha` is computed exactly as the contract does: sha256 over the raw words. `beta` and `gamma`
are computed over the reduced values. The signed hash is taken over the raw aliased nullifier,
as the contract computes it.

## Running

Both generators run inside the SDK's prover package. They use its `tests/helpers`, and
`genFieldAliasFixtures` also uses prover internals (`ZTransaction`, the UHF hash helpers). Check
out the repos side by side:

```
palliora/
  v1-sdk/           # generated with 66483ba; dev at that point is fine
  v1-circuits/      # 7270065, with artifacts/ built (dev keys)
  v1-interface/     # public/mainnet-circuits (production keys)
  v1-protocol/      # this repo
```

**SDK build used.** Jest resolves `@veilnyx-sdk/*` to each workspace package's built `dist/`.
The committed fixtures came from `v1-sdk` 66483ba (`hyperliquid/testnet-e2e`). In the SDK
packages these generators use, that commit's source matches `dev` except for a type-only change
in `shared-types`.

The `dist/` that ran matched that source exactly except in one function:
`transaction` `deriveDataEncryptionKeys` carried the refund-key fix `toBytes(h, { size: 32 })`,
the fix published in `@veilnyx-sdk/transaction@1.3.4`. It only affects memo-key derivation. Without
it, about 2.3% of keys disagree with the circuit and witness generation fails, so rerun or apply
the fix. It has nothing to do with fees, `pubAssets`, nullifiers or commitments.

Every deviation from honest SDK use is in the generator files themselves: fee fields set after
build, and `proveRaw`. There, it is deliberate: it models an attacker who does not use the SDK.

Then:

```bash
cp v1-protocol/test/security/generators/*.test.ts v1-sdk/packages/zk-prover/tests/
cd v1-sdk/packages/zk-prover
OUT=$(realpath ../../../v1-protocol/test/fixtures/data)

POC_OUT=$OUT POC_PAYMASTER=0x000000000000000000000000000000000000fE01 \
  pnpm exec jest tests/genFeeFixtures.test.ts --forceExit
POC_OUT=$OUT pnpm exec jest tests/genFieldAliasFixtures.test.ts --forceExit
POC_OUT=$OUT pnpm exec jest tests/genQueueBatchFixtures.test.ts --forceExit
```

`POC_PAYMASTER` must be the address `PaymasterFeeBacking.t.sol` deploys the Paymaster at
(`0xfe01`). The Paymaster rejects a `feeData` naming any other address.

Proofs are randomised, so regenerated files differ byte for byte from the committed ones. They
behave the same. Then run:

```bash
forge test --match-path 'test/security/*'
```

## Dev verifiers

`test/security/DevVerifier*.sol` are `snarkjs zkey export solidityverifier` outputs for the dev
keys in `v1-circuits/artifacts/{transact21,transact22,transact23,register,treeUpdate}`. Only the
contract name was changed. Each one's `delta` matches that circuit's `vKey.json`. They are wired
behind the production `Verifier` router in `FieldCanonicality.t.sol`, so only the verifying-key
constants differ from production.
