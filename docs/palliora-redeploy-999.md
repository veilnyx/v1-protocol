# Palliora redeploy of the HyperEVM (999) pool

Status: **prepared, not deployed.** This branch contains the contracts, tests, deploy tooling and
this runbook. Nothing has been sent to any chain.

The live pool `0x25913fa4a703aFF4b15b7bF00F9723dDE0446917` is replaced by a new pool deployed
from this branch. There is no upgrade path: clients move to a new account-derivation message (the
rebrand), which gives every user a new shielded key. The old pool allows one shielded address per
wallet, so existing wallets could never register their new key there. A fresh pool also starts with
a clean registry and adaptor whitelist, and with the v2 transaction hash on from the first
transaction.

## What changes in the contracts

| Change | Why |
|---|---|
| EIP-712 domain name `"Palliora"` | Rebrand. Only `initialize` reads the constant. Existing proxies keep the name stored at their initialization, so the Ethereum pool is unaffected. |
| **v2 transaction hash** (`enableTxHashV2`, one-way, called by the deploy script) | The signed hash covers every user-chosen field (commitments, amounts, notes memo, revoker, roots) plus the chain id and the pool address. Closes L-2 (one signature re-proved into other outputs) and binds proofs to one pool on one chain. |
| Revoker keys must be in the prime-order subgroup | The circuit's `ValidatePoint` accepts mixed-order points. |
| Registration rejects off-curve or degenerate public keys | The register circuit does not check them. |
| CALL_ADAPTOR with `refundAddress == 0` reverts | Its outputs would be committed to an address with no opening. |
| Commitment queue capped at capacity − 9 | Every queued leaf stays insertable by the treeUpdate circuit. |
| A deposit must credit exactly the pulled amount | Fee-on-transfer tokens revert instead of making the pool insolvent. |
| Gateway `handleWrapAndDeposit` needs `msg.value` == the wrapped deposit | No stranded wrapped surplus. |
| Already on `main`: #40 | A tree-update proof stays valid when more leaves are queued. |

The proving keys and verifiers are unchanged: production ceremony `8a65d25`, no new ceremony.
Circuit-level items (L-1 `inValues` range check, register `ValidatePoint`, treeUpdate `lastRoot`) wait
for the next ceremony.

## Evidence

- `test/security/RedeployHardening.t.sol`: 9 unit tests. They cover curve vectors including the live
  revoker keys, the v2 hash spec, field coverage and test vector, the refund address, the capacity
  boundary and fee-on-transfer.
- `test/security/RedeployForkSuite.t.sol`: **31/31** on a 999 fork, all with real Groth16 proofs from
  the production keys. Covered:
  - the honest flow;
  - legacy-, other-pool- and other-chain-signed transactions, all rejected;
  - the L-2 re-prove, rejected;
  - double spends, malleability, replay, front-running and 14 field tampers;
  - stale and unknown roots, fee abuse, tree-update forgery;
  - every registration attack;
  - note theft, refused by the circuit.

  Run it with `HYPEREVM_RPC_URL=… forge test --match-path test/security/RedeployForkSuite.t.sol`.
- Full suite: the same 13 failures as `main` (stale legacy fixtures), no new ones.
- Deploy dry run (`deployCoreWithAdp:hyperevm:fork`, 2026-10-29): every step passed. Then
  `verify-deployment.py` reported **DEPLOYMENT OK**: 25 contracts identical to this build, domain
  `"Palliora"`, `txHashVersion = 2`.

## Decisions before deploying

1. **Owner.** `common.hardwareWalletOwner` is `0xa285717B` (an EOA). It will own the Pool (including
   upgrades), the Verifier router (including `setVerifierManager`, which can swap in verifiers), the
   AdaptorHandler, the Gateway and the Paymaster. `veilnyxMultiSigAddress` `0x9bAf694B…` has no code
   on 999. Recommended: a Safe plus a 24–48 h timelock as owner, set before the live run.
2. **Revoker metadata.** `common.revokers[0]` is still named "Veilnyx Security Group", pinned at
   CID `bafkrei…y4kcq`. Rebranding it means committing a new document under `docs/` and pinning it.
   The key can stay (it is prime-order, checked).
3. **Deposit limits.** The script initializes min $10 / max $250 / TVL $5,000. The live pool runs
   min $2. After the deploy, the owner sets them with `setDepositLimits`.
4. **Screening.** Still off on 999 (`screeningDisabled: true`; there is no oracle on HyperEVM).
5. **Remaining "Veilnyx" in verified source.** `AdaptorHandler.setVeilnyxPool` / `veilnyxPool`, the
   Paymaster error `FeeAssetNotSupportedByVeilnyx`, comments, and the `@veilnyx-sdk/*` package names.
   Renaming the functions changes ABIs that the scripts and apps call. It is a separate decision.

## Client changes that must ship with the new pool

These are not in this repo. They must be live before users touch the new pool.

1. **Sign the v2 hash** whenever `pool.txHashVersion() == 2` (it reverts on pools without it: treat
   that as legacy). The spec is in `ShieldedTransactionLogic.hashV2`:

   ```
   head   = keccak256(abi.encode(uint8 txType, uint16 revokerId, addressTreeRoot, commitmentTreeRoot, feeData, refundAddress))
   arrays = keccak256(abi.encode(uint248[] pubAssets, uint256[] nullifiers, uint256[] commitments))
   memos  = keccak256(abi.encode(bytes assetsMemo, bytes keysMemo, bytes notesMemo, bytes targetData))
   txHash = uint256(keccak256(abi.encode(keccak256("Palliora.ShieldedTransaction.v2"), chainId, pool, head, arrays, memos))) % p
   ```

   Every field is taken exactly as the pool receives it (`ZTransaction.toSolidityInput()`).
   `genRedeployForkFixtures.test.ts` has a working implementation.

   Test vector: `RedeployHardening._sampleTx()` with chain 999 and pool `0x…9001` must give
   `10287438950420733548199270422711720398136271865018227309152055955606452881044`.

   The SDK needs the pool address for this. A legacy-hash client fails on the new pool with
   `InvalidTransactionProof`.
2. **Registration domain name.** Read `eip712Domain()` from the pool instead of hardcoding
   `'Veilnyx'`. Today it is hardcoded in:
   - `interface/src/components/register-modal.tsx`
   - `interface/src/hooks/useEnsureRegistered998.ts`
   - `relayer/src/register.mjs`
3. **New account-derivation message** (`SHIELDED_ACCOUNT_GEN_SIGN_MSG`). This creates the new keys.
   The reports key label `'veilnyx-grant-recipient/v1'` gets the same treatment, if it changes too.
4. **New addresses everywhere:**
   - the app's chain profile;
   - relayer, tree keeper and subgraph;
   - GasStation;
   - the burner-funding adaptor (redeploy it or point it at the new pool, then `addAdaptorSupport`);
   - the compliance explorer and revoker permits.

## Wind down the old pool (before or alongside the deploy)

1. **Do not pause it.** `transact` is `whenNotPaused`, so pausing also blocks withdrawals.
2. Stop deposits. The owner calls `setTvlLimitUsd(0)`, after which any deposit reverts with
   `TvlLimitExceeded`. Withdrawals and transfers are unaffected.
3. Keep the old pool's tree keeper running until its queue is empty. Notes still in the queue cannot
   be spent.
4. Users withdraw with the current app (old account message). Keep a withdraw-only path live until
   the pool's USDC and WHYPE are at dust. On 2026-10-29 the pool held 28.2 USDC.
5. Owner: collect any fees (`getCollectedPaymasterFee` → `withdrawPaymasterFeeFor`; withdraw fee bps
   is 0), and de-list the old funding adaptor `0x8DFc63e4` (`addAdaptorSupport(…, false)`).

## Deploy

Follow `docs/hyperevm-mainnet-deployment.md` (fresh deployer with big blocks, dry run, live run,
verification), with:

```bash
pnpm fork:hyperevm   # terminal 1
DEPLOYMENT_NAME=palliora-redeploy-999 DEPLOYMENT_PURPOSE="Palliora redeploy of the 999 pool" \
  pnpm deployCoreWithAdp:hyperevm:fork            # dry run
python3 script/hyperevm/verify-deployment.py deployments/palliora-redeploy-999-<date>-dry-run.json --rpc http://127.0.0.1:8547

DEPLOYMENT_NAME=palliora-redeploy-999 DEPLOYMENT_PURPOSE="Palliora redeploy of the 999 pool" \
  pnpm deployCoreWithAdp:hyperevm                 # live
python3 script/hyperevm/verify-deployment.py deployments/palliora-redeploy-999-<date>.json --rpc $RPC_HYPEREVM_MAINNET
```

The pool is left **paused**. Before the owner unpauses:
- `verify-deployment.py` says DEPLOYMENT OK;
- the clients above are live against the new address;
- the deposit limits and the adaptor whitelist are set;
- a small real deposit → tree update → withdraw has gone through.
