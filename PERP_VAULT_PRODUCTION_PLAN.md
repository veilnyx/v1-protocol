# PerpVault: audit findings and production-readiness plan

Scope: `src/adaptors/hyperliquid/{PerpVault,PerpVaultAdaptor,ClaimToken,IHyperCore}.sol`,
`script/hyperliquid/keeper/keeper.mjs`, and the deployment surface. Method: full
adversarial re-read of the contracts, with every claimed exploit reproduced in a
runnable PoC before being written down. PoCs live in
`test/adaptors/PerpVaultMultiUser.t.sol` (`test_poc_*`) and stay in the tree so
the fixes turn them into regression tests.

Status of the codebase going in: 45 tests passing; share accounting, exit
pricing, escrow mechanics, NAV four-location invariance, and the proportional
trim verified against live HyperCore (chain 998).

---

## 1. Findings

### C-1 (critical): phantom NAV from the withdraw-in-flight baseline

`pendingWithdraw()` measures the returning bridge credit as
`idleAssets() - idleBeforeWithdraw`, and the baseline only ever rebases upward.
Any idle **outflow** while a withdrawal is in flight (a redemption from the
buffer, a claim payout, a `postMargin`) drops idle below the baseline; when the
credit then lands, it is invisible to the measurement and `pendingWithdraw()`
keeps reporting the full in-flight amount **on top of** the credit now sitting
in `idleAssets()`.

Proven in `test_poc_withdrawBaselinePhantomNav`:

```
buffer 40k, core spot 60k, withdrawFromCore(30k), Bob redeems 35k mid-flight,
credit lands:
  reported totalAssets : 95,000
  real assets          : 65,000
  phantom              : 30,000   (46% NAV overstatement)
```

Anyone can redeem at the inflated NAV and drain the difference from remaining
holders. The mirror direction is also broken: a **deposit** landing mid-flight
is consumed by `_settleWithdraw` as a fake credit, clearing `withdrawInFlight`
early and understating NAV until the real credit arrives — cheap entry.

The same root cause exists on the Core-spot side: `settleBridge()` measures
`coreSpot() - spotBeforeBridge` while an outbound `spotSend` debits the same
balance on a delay, so running the two bridge directions concurrently corrupts
both deltas.

**Fix.** Rebase the idle baseline at the end of every function that moves the
idle balance (deposit pull, redeem payout, claim payout, `postMargin`), so
deltas are only ever measured across quiescent spans; and serialise the bridge:
`withdrawFromCore` reverts while `bridgeInFlight > 0`, `postMargin` reverts
while `withdrawInFlight > 0`. The keeper already sequences them; the contract
must enforce it.

### C-2 (critical): fresh redemptions jump the claim queue

`redeem()` pays from `idleAssets() - claimPot` without first calling
`fundClaims()`. Liquidity that lands from the unwind executed **for the queue**
sits as plain idle until someone earmarks it — and a fresh redeemer in that
window takes all of it.

Proven in `test_poc_redeemJumpsTheClaimQueue`:

```
Alice (50k) fully queued; her unwind lands as 50k idle; Bob redeems:
  Bob paid immediately : 49,955
  Alice claimable      : 0
  Alice still escrowed : 50,000 (all of it)
```

Alice waits for a second full unwind cycle; repeatable indefinitely, so a
queued exiter can be starved. The keeper's ordering ("exits before
redeployment") is intent the contract does not enforce.

**Fix.** `redeem()` calls `fundClaims()` before reading the buffer. Landed
liquidity then settles the queue first, and a new redeemer queues behind it.
One line, plus turning both PoCs into asserting regressions.

### H-1 (high): sub-$10 trims stall settlement permanently

Hyperliquid silently drops orders under $10 notional (observed live: a $9.5
trim from a 25% exit on a $40 vault produced nothing). Settlement converges
over cycles and fees leave a residue, so every queue's tail eventually
produces a trim below the minimum: no unwind, no funding, a permanently
unsettled remainder. Low-leverage vaults hit it soonest.

**Fix.** Keeper-side: when the required trim is under the minimum, widen it to
the minimum (over-trimming is a slight de-lever — safe direction) or, when the
whole remaining queue is worth less than the minimum, fund it from the buffer
and let the next rebalance absorb the drift. Add a contract-side
`minOrderNotional` constant so `rebalance()` knows a sub-minimum order is a
no-op and emits accordingly instead of pretending it traded.

### H-2 (high): the keeper key is owner-grade in practice

`placeOrder()` bypasses every safety bound in `rebalance()` — oracle-deviation
gate, slippage bound, cooldown, 5-sig-fig rounding — and `moveUsdClass()` is
unbounded. A leaked keeper key bleeds the vault through deliberately bad fills
into a colluding counterparty. The drill needed `placeOrder` once (testnet
bootstrapping); production does not.

**Fix.** Either remove `placeOrder` or constrain it to the same
oracle/slippage bounds with `reduceOnly` forced on. Ops-side: keeper key
separate from owner; owner a multisig; keeper permissions documented in §6.3.

### H-3 (high): claim-pot blending reprices settled exits

`claim()` pays `amount * claimPot / claimSharesSettled` across all settled
tranches. A holder settled at rate 1.0 who claims after a later tranche
settles at 0.5 receives the blend, not their strike — the post-exit market
exposure the share-denominated redesign removed comes back through the pot.
Bounded (only blends settled tranches, and prompt claiming avoids it), but it
contradicts the "your price is struck at settlement" contract.

**Fix (decide one).** (a) Accept and document, with the keeper settling
frequently so tranches are small; (b) checkpoint a cumulative
paid-per-share accumulator so each CLAIM token claims at the rate of its own
settlement epoch. (b) is correct but adds state; (a) is defensible for launch
if disclosed. Decision item.

### H-4 (high): dislocation gate blocks pure queueing

`redeem()` reverts on `PriceDislocated` even when the buffer is empty and the
redemption would only escrow shares — an operation that needs no price at all
(the exit is priced later, at settlement, by design). Exactly during the
volatility that makes people want out, exit *intent* is blocked.

**Fix.** When the mark is dislocated, allow the escrow-only path (queue
everything, pay nothing now) instead of reverting. Payment legs stay gated.

### H-5 (high): no deployment pipeline, and configuration is unvalidated

`DeployHyperEvm.s.sol` does not deploy the vault; the drills used bare
`forge create`. CLAIM and share tokens are registered nowhere. The first
testnet vault shipped with asset = USD₮0 against `coreTokenIndex` = 0 (USDC) —
a pairing that strands every bridge, caught only by later inspection.

**Fix.** A `DeployPerpVault.s.sol` that deploys vault + registers share and
CLAIM assets in the Pool + asserts configuration: asset decimals vs
`PERP_USD_DECIMALS` handling, `coreTokenIndex`'s linked `evmContract` equals
`asset` (from spot metadata, asserted off-chain in the script), perp index
exists and `maxLeverage ≥ target`, keeper and owner set to intended addresses.
Plus a post-deploy checklist that runs the state probes from the drill.

### M-1 (medium): maintenance margin ignores margin tiers

`maintenanceMargin() = notional / (2·maxLeverage)` matches HyperCore only in
the lowest tier (verified to 0.006% at drill size). Large positions sit in
higher `marginTableId` tiers with larger requirements, so at size the vault
understates maintenance and the distress latch fires late.

**Fix.** Cap vault TVL (deposit cap) below the first tier boundary for launch;
reading the tiered table is a fast-follow.

### M-2 (medium): Core spot is unrecoverable

`withdrawFromCore` can only target the token's system address. A broken or
wrong link strands funds permanently (~80 testnet USDC currently stranded in
drill vaults). An owner sweep fixes it but is an admin power over user funds.
Decision item for §6.3; if adopted, timelock it.

### M-3 (medium): economic parameters are defaults, not decisions

`entryFeeBps = 10` covers round-trip exchange fees (9bp measured) but was
never sized against §4.2's finding (a deposit-forced rebalance cost an
incumbent 3.86% in the modelled path). Escrowed exiters also still capture a
sliver of entry fees via NAV. Funding drag (-21.97%/yr at 2x on flat price)
has no UI disclosure yet. These are launch decisions, not code.

### M-4 (medium): hygiene

No events on setters; `setKeeper` accepts zero address;
`setTargetLeverageBps` mid-queue changes trim behaviour silently (document);
`claimableShares()` is global-settled-capped, fine, but name suggests
per-holder — document.

### V (verification gaps)

- The spot→EVM credit has never run against a working linked ERC20 (testnet
  USDC's link is a dead proxy). Mainnet-only; must be staged with small size.
- No invariant/fuzz suite. The invariants are now crisp enough to encode:
  (i) `totalAssets` equals the sum of real balances across all five locations
  minus `claimPot` under any interleaving of operations; (ii) settlement and
  queueing never move `pricePerShare`; (iii) `claimPot` is always payable;
  (iv) no operation mints value (Σ user outcomes ≤ Σ deposits ± market PnL).
  C-1 would have been caught by (i) immediately.
- The fixture path (`perp_vault_deposit_10_usdc.txt` through the real Pool
  with `vm.etch`) is still unwritten, so the shielded e2e is unproven.
- No external review has seen any of this code.

---

## 2. The plan

Phases are ordered by dependency; each has a gate. Sizes: S ≤ ½ day, M ≤ 2
days, L is a week-class item.

### P0 — correctness (blockers: C-1, C-2) — M
1. Rebase-on-move for the idle baseline; serialise bridge directions. [C-1]
2. `fundClaims()` at the top of `redeem()`. [C-2]
3. Turn both PoCs into asserting regression tests; add the deposit-mid-flight
   and concurrent-bridge variants.
**Gate:** all PoCs assert the fixed behaviour; 45+ tests green.
**Status: DONE.** Baseline rebases at the end of every idle-moving function
(deposit, redeem, claim, postMargin); bridge directions serialised via
`BridgeBusy` (inbound also blocks `moveUsdClass`, which moves the measured spot
balance; outbound does not block it — nothing measures spot then); `redeem()`
runs `fundClaims()` before reading the buffer. Regressions:
`test_withdrawBaselineSurvivesIdleOutflow`,
`test_depositMidFlightIsNotMisreadAsBridgeCredit`,
`test_bridgeDirectionsAreSerialised`, `test_redeemCannotJumpTheClaimQueue`.
47 tests green. Keeper defers exit legs while an inbound bridge is in flight.

### P1 — hardening (H-1 … H-4) — M/L
4. Min-order handling in keeper + `minOrderNotional` awareness in
   `rebalance()`; buffer-funds-the-tail rule. [H-1]
5. Constrain or remove `placeOrder`; bound `moveUsdClass`. [H-2]
6. Escrow-only redemption under dislocation. [H-4]
7. Claim-rate decision: **RESOLVED — blend, documented.** The per-epoch
   accumulator turned out to conflict with the note model: paying each tranche
   at its own strike requires tying a CLAIM token to its settlement epoch, and
   CLAIM is a fungible bearer asset registered once in the Pool — per-epoch
   rates would need per-epoch asset ids, the exact cost this design already
   rejected for Option B deposits. The blend's exposure is bounded by NAV
   movement between settlements; the keeper settling every tick keeps tranches
   small. Documented on claim(). [H-3]
8. Setter events, zero-checks, doc fixes. [M-4]
**Gate:** keeper drill on testnet exercises the sub-minimum tail to a fully
settled queue.
**Status: DONE.** Drill vault `0x2024F614260025648ebC82498A61f3Fdd8D23b9F`
(chain 998, real Core margin, 2x BTC): a $4 queued exit produced a $7.71
required trim; the vault widened it (`TrimWidened $7.71 -> $10.50`), sent
$10.79 wire, and got a REAL fill — Close Long 0.00015 BTC @ 72,297 ($10.84).
Margin floor blocked a near-total `moveUsdClass` pull live; a sane pull
passed; queue settled to zero escrow and the claim paid.

The drill also caught a rounding bug the unit suite had missed: the first
attempt widened the NOTIONAL to $10.00 but the size division FLOORED, sending
$9.39 — dropped silently again. Fixed by widening to $10.50 (execution-price
headroom) and CEILING the size for widened trims. The unit harness missed it
because it accepted all orders; it now drops sub-$10 notionals exactly like
the exchange. The dead-link spot->EVM leg remains simulated (testnet USDC has
no working linked ERC20) — unchanged, tracked under P4 canary.

### P2 — deployment pipeline (H-5, M-1) — M
9. `DeployPerpVault.s.sol` with config assertions; Pool registration of share
   + CLAIM assets; post-deploy probe checklist.
10. Deposit cap (launch TVL below tier-1 margin boundary). [M-1]
11. Frontend/SDK: CLAIM asset support, `claimableShares` in the UI, funding
    disclosure. [M-3]
**Gate:** one-command testnet deploy producing a correctly configured vault,
verified by the probe checklist.
**Status: DONE.** `DeployPerpVault.s.sol` deployed vault
`0x22eadA81D357bEBAB306D08373a88e65C13B587d` on 998 in one command: cap set
(500 USDC), share registered as Pool asset 65540, CLAIM as 65541, adaptor at
`0x31B48E0c...41EF`. Pre-flight asserts run against the REAL node via raw
eth_call (HyperCore precompiles have no bytecode, so fork simulation cannot
execute them): evm-link pairing, bridge scale == 100, 6dp asset, perp exists,
target <= market max leverage, cross margin, real cap. Negative test confirmed
the script REJECTS the exact USD-T0/USDC misconfiguration that shipped once.
`verify-vault.sh` probes 9 checks post-deploy: 8/9 on the drill vault, the one
FAIL being the intentionally unlinked mock asset (ALLOW_BROKEN_LINK, testnet
only). The tokenInfo precompile (0x80C) is now bound in IHyperCore with
field order verified on chain.

Item 11 (frontend/SDK: CLAIM support, claimableShares in the UI, funding
disclosure) is deliberately NOT part of this gate — it is workstream-D UI work
with no deploy dependency. Deposit cap (item 10) shipped: checked on
post-deposit totals, lowering strands nobody, default uncapped only so test
harnesses stay independent; deploys must set it and the script enforces that.

### P3 — verification — L
12. Invariant/fuzz suite over operation interleavings (the four invariants
    above).
13. Fixture e2e through the real Pool (`vm.etch` at the fixture addresses).
14. Fresh testnet lifecycle drill on the final bytecode: deposit → bridge →
    open → queue → trim → return → settle → claim, keeper-driven end to end.
15. External review of the four contracts (small surface: ~1,200 lines).
**Gate:** invariants run clean; external findings triaged to zero
criticals/highs.

### P4 — launch operations — M
16. Mainnet canary: real USDC link, deposit cap in the hundreds, the
    spot→EVM leg verified with small size first. [V]
17. Monitoring: NAV vs precompile reconciliation, queue age alarm, distress
    latch alarm, keeper liveness, funding-drag tracking.
18. Runbook: liquidation response, dislocation response, keeper key rotation,
    §6.3 powers documented (sweep decision recorded either way). [M-2]
**Gate:** canary runs a full week including at least one queued exit settled
end to end; then raise caps stepwise.

### Decision items (yours, not code)
- H-3: blend vs per-epoch claim rates.
- M-2: owner sweep for stranded Core spot — yes/no, and timelock if yes.
- M-3: entry fee size; funding-drag presentation; launch leverage/vault set
  (§6.5).
- Owner key arrangement (multisig membership, keeper key custody).

