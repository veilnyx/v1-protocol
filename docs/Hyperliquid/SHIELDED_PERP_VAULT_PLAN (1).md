# Shielded perp vaults: development plan

Status: **plan only, nothing implemented.**

Numbers in section 4 are produced by `docs/vault_shares_sim.py`. Re-run it after
changing any parameter rather than editing the tables by hand.

---

## 1. What this is

A set of fixed-strategy leveraged vaults on HyperCore — `BTC-LONG-10x`,
`BTC-SHORT-10x`, `ETH-LONG-2x` and so on — each operated by Veilnyx as a rule,
not a discretionary fund. Users deposit through the shielded pool and receive an
**encrypted note holding vault shares**, priced at the vault's NAV at deposit
time. Redemption spends the note and returns USDC at the prevailing NAV.

State the claim precisely:

> **This is a leveraged token with private ownership.** The vault's position is
> public and openly Veilnyx's. What is hidden is who owns the shares.

### What the depositor does control

- **Size.** Deposit any amount. Shares are allocated pro rata, so effective
  exposure is share fraction × vault position — the depositor sets their own
  exposure by choosing how much to put in.
- **Entry.** Deposit timing sets the NAV the shares are struck at, and the
  holder's P&L runs from that NAV onward. Entering later at a higher NAV buys no
  part of earlier gains, and entering after a drawdown buys in at the lower NAV.
- **Exit.** Redeem at any time at the prevailing NAV, in whole or in part.

### What the depositor does not control

- **Asset, direction and target leverage.** Fixed per vault. The choice is which
  vault to enter, from the menu Veilnyx operates.
- **Execution.** Entry is struck at NAV, which is a mark, not a fill. The trades
  backing it are the vault's, and a deposit forces a rebalance at a price the
  depositor does not choose. §4.2 shows this mattering more than it sounds.

### Privacy

Deposits and redemptions are ordinary shielded transactions, so the **amount is
public** in `pubAssets` while the **depositor is not**. There is no second
on-chain event to correlate against — the shielded transaction interacts with the
adaptor directly — so the anonymity set is simply everyone who has deposited into
that vault.

Position-level privacy is **not** offered and must not be claimed. The vault's
position, size, direction, entry and liquidation price are all public on
Hyperliquid, permanently, and openly attributable to Veilnyx.

One caveat that matters most exactly when a vault is new: **the anonymity set is
only as large as the depositor base.** A depositor who dominates a small vault has
effectively no privacy — the vault's public position is their position, and its
size moves when they move. Privacy here improves with adoption rather than being
guaranteed by construction, and the UI should not imply otherwise to the first
depositors.

---

## 2. Why the share note works with no protocol changes

The deposit path is structurally identical to the Morpho vault-share adaptor that
already runs on Ethereum mainnet:

1. User sends a `CALL_ADAPTOR` shielded transaction spending USDC notes.
2. The adaptor routes USDC to the strategy's vault contract and receives share
   ERC20 back.
3. `_handleAdaptorCall` (`src/libraries/ShieldedTransactionLogic.sol:601-620`)
   mints `Poseidon(shareAssetId, refundAddress, shares)` and emits the encrypted
   refund memo.
4. The user later spends that note to redeem.

**No circuit change. No `ShieldedTransactionLogic` change.** The share token is
just another registered asset, exactly as a Morpho vault share is. The output
value of a `CALL_ADAPTOR` transaction is determined on-chain after execution and
committed to `refundAddress`, which is precisely what is needed when the share
count is not known until the vault computes NAV.

### 2.1 Relationship to ERC-4626 and ERC-7540

**Use ERC-4626 for the share and NAV accounting.** `totalAssets`,
`convertToShares`, `convertToAssets` and the share ERC-20 are exactly the maths in
§4, and there is no reason to invent a private variant.

**Do not implement ERC-7540 literally**, despite it being Final and despite async
vaults being precisely the problem class here. Three concrete blockers:

1. **The Claim state cannot be skipped, but the adaptor interface is synchronous.**
   ERC-7540 requires `requestDeposit` and the later `deposit` claim to be separate
   calls. But `AdaptorHandler.handleAdaptor` checks
   `IERC20(asset).balanceOf(address(this)) >= outAssets[i].value` before approving
   to the Pool, and `_handleAdaptorCall` mints commitments from whatever comes back
   **in that same transaction**. A literal async vault returns nothing claimable, so
   the Pool would commit nothing.
2. **Requests are keyed to a `controller` address and are deliberately not
   tokenised.** The spec explicitly avoids ERC-721/1155 for pending claims. Veilnyx
   holds ownership in a commitment, not an address mapping — every request would be
   controlled by the single `AdaptorHandler`, so the vault could not distinguish
   users. That is fine in itself, but it means the claim must be a Veilnyx note,
   which is the one representation ERC-7540 declines to standardise.
3. **`previewDeposit` and `previewRedeem` MUST revert** on async vaults, so the SDK
   and UI cannot quote expected shares through the standard path and need a
   vault-specific quote function.

**Do steal ERC-7540's semantics, with the request receipt tokenised.** That single
change makes asynchrony fit the existing synchronous interface with no protocol
work:

```
leg 1  CALL_ADAPTOR: spend USDC notes -> vault mints CLAIM token -> Pool commits claim note
       (vault batches, bridges, and executes the rebalance in between)
leg 2  CALL_ADAPTOR: spend claim note -> vault burns CLAIM, returns SHARES -> Pool commits share note
```

Both legs are ordinary synchronous `CALL_ADAPTOR` transactions returning an ERC-20.
The asynchrony is carried by the claim token being a real registered asset. The
same pattern runs in reverse for redemption when the buffer is insufficient.

**The `requestId` design is worth copying directly.** ERC-7540 requires that
requests sharing a `requestId` "MUST transition from Pending to Claimable at the
same time and receive the same exchange rate", with partial fulfilment applied
pro-rata across the whole batch. That is an epoch model, and it buys four things
here: no race to redeem first at a stale NAV, one aggregated unwind order instead
of N, exact cost attribution (§6.1), and — because the position moves once per
epoch for the aggregate — an observer cannot map individual redemptions to
position deltas.

---

## 3. Architecture: one contract per strategy

This is the load-bearing structural decision. It is forced by two constraints,
both verified rather than assumed.

### 3.1 What HyperCore permits a contract to do

CoreWriter (`0x3333333333333333333333333333333333333333`) is the only write path
from HyperEVM to HyperCore. Its action set is ids **1–13 and 15–17** — id 14 is
absent — covering limit orders, cancels, vault and spot transfers, USD class
transfer, staking, delegation, API wallet registration, builder fees, borrow/lend
and abstraction mode. Encoding is a version byte `0x01`, a 3-byte big-endian
action id, then the ABI-encoded payload.

Two things are **not** in that set and therefore impossible from a contract:

- **Updating leverage or margin mode.** There is no action for it, and action 1
  (limit order) carries no margin-mode field, so it cannot be selected per order
  either. Verified on chain 998: precompile `0x800` returns
  `Position{int64 szi, int64 entryNtl, int64 isolatedRawUsd, uint32 leverage, bool isIsolated}`,
  and a fresh account reads `leverage=10, isIsolated=false`. A contract's account
  is stuck at cross margin under a 10x cap.
- **Creating or controlling sub-accounts.** `createSubAccount` is **an**
  exchange-endpoint action requiring an ECDSA signature the contract cannot
  produce, and it is volume-gated regardless.

A further constraint: **one HyperCore account holds one position per asset.**
Isolated margin would not change this — it is scoped per (account, asset), not per
position, so two strategies on the same asset in one account net into a single
position with a single liquidation price.

### 3.2 Why that forces per-strategy contracts

`src/base/PoolStorage.sol:16` declares a single `IAdaptorHandler public
adaptorHandler`, assigned once at init (`src/core/Pool.sol:84`) with no setter.
Every adaptor is `delegatecall`ed through that one handler, so under
`delegatecall` **the handler is the CoreWriter caller and therefore the HyperCore
account**. One Pool would mean one Core account — and by §3.1, `BTC-LONG` and
`BTC-SHORT` behind it would net into one position, with all strategies sharing
cross margin that cannot be walled off.

The fix requires no Pool change: **give each strategy its own contract**, invoked
by a normal `call` rather than `delegatecall`.

```
Pool ──delegatecall──> AdaptorHandler ──call──> PerpVaultAdaptor
                                                      │
                                        ┌─────────────┼─────────────┐
                                        ▼             ▼             ▼
                                  BtcLong10x    BtcShort10x    EthLong2x
                                  (own Core     (own Core      (own Core
                                   account)      account)       account)
```

Because CoreWriter sees each vault contract as `msg.sender`, each gets its own
HyperCore account. Consequences:

- `BTC-LONG` and `BTC-SHORT` coexist without netting.
- Liquidation containment is **stronger than isolated margin** — the accounts are
  entirely separate, not merely walled off within one.
- Leverage tiers work. The 10x cap is a *ceiling*, not a mandate; effective
  leverage is notional ÷ equity, chosen by position sizing. Anything **above**
  10x remains impossible, since the cap cannot be raised from a contract.

Each vault contract holds its Core account, its position, its share ERC20 and its
rebalancing rule.

### 3.3 Moving value between HyperEVM and HyperCore

The pool holds ERC20s on HyperEVM; margin lives on Core. Linked tokens cross by a
plain ERC20 `transfer` to the token's Core system address — first byte `0x20`,
remaining bytes zero except the big-endian token index. Spot then moves to perp
margin via CoreWriter action 7, `usdClassTransfer(ntl, toPerp)`. The return trip
is a spot send back to the same system address.

Latency differs by action and matters for rebalancing: **order actions and vault
transfers are deliberately delayed a few seconds**; USD class transfers and spot
sends are not.

### 3.4 What a deposit actually does, step by step

A new deposit is new **margin**, and the position scales because target notional
is `L × E`. But only the first step is synchronous with the shielded transaction:

| # | Step | Synchronous? |
|---|---|---|
| 1 | USDC lands at the vault contract on HyperEVM; **shares are minted at pre-deposit NAV** | yes — same transaction |
| 2 | ERC20 transfer to the Core system address credits the vault's Core **spot** balance | no — credited by a system transaction after the EVM block |
| 3 | `usdClassTransfer(ntl, toPerp=true)` moves spot → **perp margin** | yes — class transfers are not delayed |****
| 4 | Rebalance order brings notional to `L × E` | no — order actions are delayed a few seconds and fill at an unknown price |

Three consequences that have to be designed for, not discovered:

- **Shares must be struck at *pre-deposit* NAV.** Standard ERC-4626 discipline: compute NAV, mint `D / NAV`, then credit the deposit. Getting the order wrong lets a depositor buy their own money.
- **NAV must count both sides of the bridge.** Equity is *Core account equity (from precompiles) + idle USDC held on the HyperEVM side*, not just the Core figure. A deposit sits on the EVM for a step or two, and NAV that reads only `0x80f` would omit money the vault demonstrably holds.
- **The vault is briefly under-levered.** Between steps 1 and 4 the equity has grown but the position has not. Price moves in that window are shared at below-target exposure. This is tracking error, it is unavoidable given the order delay, and it is part of why the entry fee in §6.1 must be sized conservatively rather than to the theoretical minimum.

Redemption runs the same pipeline in reverse and is slower, because funding it
from the position requires an order (delayed, unknown fill) before any transfer
can happen. That is what the buffer in C3 exists to avoid — at a cost, since
buffered equity is not posted as margin and therefore pushes the Core account's
real leverage above the vault's headline figure. See C3.

---

## 4. Financial mechanics, worked

All figures from `docs/vault_shares_sim.py`. Taker fee 4.5bp; maintenance margin
at Hyperliquid's rule of `notional / (2 × maxLeverage)`.

### 4.1 Share accounting — two depositors at different NAVs

`BTC-LONG-10x`. Alice deposits 10,000 at BTC 100k. Price rises to 102k. Bob
deposits 12,000. Price falls back to ~100k.

```
event                                BTC      equity     size     shares      NAV    lev     liq px
---------------------------------------------------------------------------------------------------
Alice deposits 10,000            100,000    9,955.00   0.9955     10,000   0.9955  10.00     94,737
BTC 100k -> 102k                 102,000   11,946.00   0.9955     10,000   1.1946   8.50     94,737
Bob deposits 12,000              102,000   23,883.94   2.3416     20,045   1.1915  10.00     96,632
BTC 102k -> 99.96k                99,960   19,107.15   2.3416     20,045   0.9532  12.25     96,632

holder         shares     paid in   value now         P&L   return
------------------------------------------------------------------
Alice          10,000   10,000.00    9,532.03     -467.97  -4.68%
Bob            10,045   12,000.00    9,575.12   -2,424.88 -20.21%
```

This is the core mechanism and it behaves correctly. Bob pays NAV 1.1946, which
already contains Alice's gain, so he buys **no part of it** — he tracks NAV only
from his own deposit onward. Alice's earlier entry is preserved in her share
count, not in any per-user entry price. **The note holds shares; NAV does the rest.**

Note also that Alice ate the entire opening taker fee — NAV drops to 0.9955
immediately. The first depositor into an empty vault always does.

### 4.2 The finding that shapes the product: deposits tax existing holders

Same vault, same price path, but Bob never deposits:

```
Alice alone      :   9,915.18
Alice with Bob   :   9,532.03
cost to Alice    :    -383.15  (-3.86%)
```

Bob's deposit forced a rebalance that bought **1.35 BTC at the local high of
102k**, and Alice owns roughly half of that purchase. She is 3.86% worse off purely
because Bob arrived when he did.

Morpho has no such effect — it is unlevered and never rebalances, so a deposit is
inert to existing holders. A leveraged vault **must** trade on every deposit, and
that trade's cost and entry price are socialised across everyone.

There is a genuine tension here: charging the entry cost to the depositor
correctly requires knowing the fill price, but fills are asynchronous while share
minting is synchronous. So synchronous NAV minting **inherently** socialises entry
cost. The practical mitigation is an **entry fee** sized conservatively to cover
expected rebalance cost and impact, with any excess accruing to the vault — that
is, to existing holders. Rebalance banding, trading only when leverage drifts
outside a tolerance, reduces frequency but does not fix entry timing. **This must
be designed before launch, not after.** See §6.1.

### 4.3 Liquidation is closer than it looks — but is not a wipeout

```
event                                BTC      equity     size     shares      NAV    lev     liq px
---------------------------------------------------------------------------------------------------
Alice deposits 10,000            100,000    9,955.00   0.9955     10,000   0.9955  10.00     94,737
BTC -> 98,000                     98,000    7,964.00   0.9955     10,000   0.7964  12.25     94,737
BTC -> 96,000                     96,000    5,973.00   0.9955     10,000   0.5973  16.00     94,737
BTC -> 95,000                     95,000    4,977.50   0.9955     10,000   0.4978  19.00     94,737
BTC -> 94,700  << LIQUIDATED      94,700    4,678.85   0.9955     10,000   0.4679  20.15     94,737
LIQUIDATED, position closed       94,700    3,693.69   0.0000     10,000   0.3694   0.00          -
```

Two separate facts, and the second is easy to get wrong.

**Liquidation arrives early.** The trigger is at 94,737 — only **5.26% below
entry**, not 10%. Maintenance margin at `notional / (2 × maxLeverage)` is what
does it: a 10x vault is roughly 5% from liquidation, not 10%.

**But it is not a total loss.** The maintenance requirement is precisely the
buffer that survives. NAV is **0.4679 at the trigger**, and **0.3694 once the
position is closed** and liquidation costs are paid — a 63% loss on Alice's
10,000, not a 100% loss. The vault contract, its Core account and every
outstanding share note all remain alive and redeemable.

The post-close figure assumes a liquidation cost of 1% of notional on top of the
taker fee. That is an **assumption in the simulation, not a measured value**. An
orderly book liquidation is cheaper; a gapping market that reaches backstop
liquidation can take the entire remaining balance. **Residual value is a range
with zero at the bad end**, and the design must not assume the good end.

### 4.4 After liquidation: the same vault restarts correctly

Carol deposits 5,000 into the same vault after the liquidation above:

```
LIQUIDATED, position closed       94,700    3,693.69   0.0000     10,000   0.3694   0.00          -
Carol deposits 5,000              94,700    8,654.57   0.9139     23,537   0.3677  10.00     89,716
```

Carol pays NAV 0.3694 and receives 13,537 shares for her 5,000. Alice's 10,000
shares are worth 3,677.

**The arithmetic is fair in both directions.** Carol does not buy any part of
Alice's loss — she buys in at the post-liquidation NAV, and her forward P&L runs
from there. Alice is not rescued by Carol's arrival either; her loss was realised
in NAV before Carol appeared. Restarting the same vault requires no special
handling: NAV accounting already does the right thing.

One detail worth seeing: Alice goes from 3,693.69 to 3,677.07 the moment Carol
deposits. That is the §4.2 entry externality again, and it bites **harder** after
a liquidation, because the residual equity is small so each new deposit is large
relative to it.

### 4.5 Volatility decay: price flat, vault down 32%

Twenty moves, +2% then −1.96% repeated, ending at exactly the starting price,
rebalancing to target each time:

```
    target   final equity    return      fees
  -----------------------------------------
        2x       9,909.38   -0.91%     12.62
        5x       9,188.92   -8.11%     58.48
       10x       6,835.43  -31.65%    194.00
```

Price is unchanged and every vault has lost money. This is intrinsic to any
rebalanced leveraged product — not a bug, not recoverable by better execution.

**Product recommendation: do not launch a 10x vault.** A −31.65% outcome on a flat
market will be experienced as a malfunction regardless of what the documentation
says. Launch 2x, and add higher tiers only once holding-period behaviour is
understood and clearly communicated.

### 4.6 Funding is a first-order effect and is not yet modelled

A perpetual position pays or receives funding continuously, and the simulation
above ignores it entirely. For a leveraged vault this is **not** a rounding error:
funding accrues on **notional**, so a 10x vault feels it at ten times the rate its
equity would suggest. A funding rate that looks negligible per 8-hour period
becomes a material, persistent drag on NAV at leverage.

It also makes the long and short vaults **economically asymmetric rather than
mirror images**:

- A perpetually-long vault in a market where longs pay funding bleeds continuously,
  on top of the decay in §4.5.
- The matching short vault *receives* that funding, and is paid to hold the
  opposite exposure.

So `BTC-LONG-2x` and `BTC-SHORT-2x` are not two sides of one coin — over any
meaningful holding period their returns are not symmetric around the price move,
and in a persistently one-sided funding regime the losing side is structurally
disadvantaged.

Two consequences: funding must be added to `docs/vault_shares_sim.py` before any
launch decision (workstream E), and the UI must show the vault's realised funding
cost rather than only its price performance, or holders will not understand why a
flat market cost them money.

---

## 5. Workstreams

Sized S/M/L. `P0` blocks a first internal demo.

### A. Vault contract `[P0, L]`

| | Task |
|---|---|
| A1 | `PerpVault` contract: own Core account, share ERC20 (mint/burn), NAV computation, deposit/redeem. The share token **must be non-rebasing** — see §6.2; a rebasing token silently breaks note accounting. |
| A2 | NAV from precompiles — `0x800` position, `0x80f` margin summary, `0x806` mark price — **plus idle USDC held on the HyperEVM side** (§3.4), with staleness and sanity bounds. Mint at pre-deposit NAV. |
| A3 | Bridge in/out per §3.3: ERC20 to the Core system address, then `usdClassTransfer` spot → perp. |
| A4 | CoreWriter order construction: version byte `0x01`, 3-byte big-endian action id, ABI-encoded payload. Action 1 for orders, 10/11 to cancel. |
| A5 | Rebalance logic with banding, and the entry-fee mechanism (§6.1 Option A). Keep ERC-4626 accounting; shape the adaptor payload so the ERC-7540-style epoch/claim-token path in §2.1 can be retrofitted without a rewrite. |
| A6 | Liquidation handling per §6.2: detect, freeze deposits, keep redemptions open at residual NAV, and require an explicit operator action to resume. Must distinguish a **partial** liquidation — which leaves a reduced position and should be handled as an ordinary bad rebalance — from a full one. |
| A7 | Admin surface: pause, parameter bounds, and an explicit statement of what admin can and cannot do. |
| A8 | De-risk band (§6.2): below a configurable multiple of maintenance margin — 1.5× to start — reduce leverage instead of holding target, and top margin up from the EVM-side buffer. This is the chosen alternative to an insurance fund, so it is load-bearing, not a nicety. |

### B. Adaptor `[P0, S]`

| | Task |
|---|---|
| B1 | `PerpVaultAdaptor` extending `AdaptorBase`, `handleAssets` with DEPOSIT/REDEEM, routing to the vault named in the payload. Mirrors `MorphoVaultAdaptor` closely. |
| B2 | Register each share token as a Pool asset with an `AggregatorV3` feed — `_getUsdValue` (`src/core/Pool.sol:665-680`) reads `latestRoundData` for TVL. A NAV shim is needed per vault. |
| B3 | Whitelist the adaptor via `addAdaptorSupport`. |

### C. Operations `[P0, M]`

| | Task |
|---|---|
| C1 | Per-vault Core account activation — an address becomes a Core user only by receiving a Core asset. Note the gotcha: if the funding account is in `unifiedAccount` abstraction mode, `spotSend` is rejected outright; use `sendAsset` with the dex named `"spot"` on **both** sides (`""` means the default perp dex and is also rejected). Check `{"type":"userAbstraction","user":...}` on the funder first. |
| C2 | Keeper for periodic rebalancing, with alerting when it fails. |
| C3 | Redemption liquidity: buffer sizing, or a claim-note path if a buffer proves insufficient. Closing a position to fund a redemption is subject to the few-second order delay in §3.3. **Note the trap:** a buffer held on the EVM side is equity that is not posted as margin, so the Core account's real leverage exceeds the vault's headline leverage and its liquidation price moves closer. A 2x vault holding 10% of equity as buffer runs 2.22x on Core, shifting liquidation from roughly −45% to −40%. Mitigation is to top margin up from the buffer as the position approaches maintenance — class transfers are not delayed, so this is fast — but it must be an explicit rule, not an emergent behaviour. |
| C4 | Monitoring: NAV, effective leverage, distance to liquidation, per vault. |

### D. SDK and UI `[P1, M]`

Deposit/redeem flows, share-note display, and — non-negotiable — decay and
liquidation disclosure at the point of deposit, not buried in documentation.

### E. Simulation `[done, extend as needed]`

`docs/vault_shares_sim.py` currently covers share accounting at differing NAVs,
the entry externality, liquidation, post-liquidation restart, and volatility decay.

Not modelled, in rough order of how much each could move a launch decision:

| Gap | Why it matters |
|---|---|
| **Funding payments** | §4.6 — first-order at leverage, and the source of long/short asymmetry. Highest priority. |
| Order delay and partial fills | Rebalances do not execute at the price the decision was made on. |
| Redemption slippage beyond taker fee | Determines whether a buffer is optional or mandatory. |
| Oracle/mark divergence | Feeds directly into the §6.4 manipulation surface. |
| Liquidation cost | Currently a flat 1%-of-notional **assumption**, not measured. §4.3's residual figure moves with it. |

Extend before launch, funding first.

---

## 6. Open decisions

### 6.1 Synchronous minting with an entry fee, or ERC-7540-style epochs?

§4.2 shows a depositor imposing 3.86% on an existing holder. This is now a clean
fork rather than an open-ended question, because §2.1 shows the epoch route is
reachable with no protocol change.

**Option A — synchronous mint at NAV, plus an entry fee.** One transaction, shares
immediately. The fee is an *estimate* of rebalance cost and impact, so attribution
is approximate by construction; set it conservatively and let the excess accrue to
existing holders.

**Option B — ERC-7540-style epochs with a tokenised claim.** Deposits collected
during an epoch, one aggregated rebalance at epoch close, share price struck from
the **actual executed fill**. Entrants pay their own entry cost exactly, so the
externality disappears rather than being approximated. Also batches the unwind,
removes the redeem-first race, and hides individual flow inside aggregate position
moves.

The cost of B is a second shielded transaction to claim — extra proof, extra fee,
and a materially worse UX — plus a claim token per epoch to register as a Pool
asset, and holders who never return to claim.

**Recommendation: A for the first vault, designed so B can be added later.** The
externality is real but bounded, and proving the whole loop end to end matters more
than optimising entry attribution before a single vault exists. Keep the claim-token
path in mind when designing the adaptor payload so retrofitting B is not a rewrite.
Note that redemption may need B's machinery regardless whenever the buffer is
insufficient (C3), so the claim token is likely to exist anyway.

### 6.2 What happens to notes when a vault is liquidated?

§4.3 and §4.4 settle the mechanics: notes survive, they reprice to the
post-liquidation NAV, and the same vault can accept new deposits with no special
accounting. **Recommendation: halt, then resume on an explicit human action —
never auto-restart.**

- **Notes must stay redeemable, always.** A note is a bearer commitment in the
  tree, unspent until spent. Someone can surface a year-old share note at any
  time. This means a vault contract can never truly be retired — deploying a
  replacement leaves an indefinite obligation to keep the old one redeemable. That
  alone argues for reusing the same vault rather than rolling a new one per
  incident.
- **Freeze deposits on liquidation; keep redemptions open.** Holders should be able
  to exit at residual NAV immediately. Redemption at that point is fast, since
  there is no position to unwind and therefore no order delay — just a class
  transfer and a spot send.
- **Require an operator action to resume.** Not because the arithmetic needs it —
  §4.4 shows it does not — but because a liquidation is evidence that something may
  be wrong: keeper failure, mis-set bands, or a market the parameters do not suit.
  Automatically reopening a position into those same conditions is how the residual
  gets lost too.
- **Recovery is asymmetric and must be said plainly.** From NAV 0.3694, getting
  back to 1.0 requires a **171% gain**. A depositor still holding after a
  liquidation should be told that in those terms, not shown a percentage drawdown.

#### Share rebase after liquidation: **no**, and this is structural, not cosmetic

Rebasing share counts so NAV returns to 1.0 is not available here, for two reasons
that both come from the note model rather than from taste:

1. **Notes are immutable commitments.** A holder's balance is
   `Poseidon(shareAssetId, owner, value)`, already inserted in the tree. The vault
   cannot rewrite it. Rebasing would require every holder to migrate to a new share
   token — a mandatory migration that strands anyone who does not return, against a
   note that is supposed to stay redeemable indefinitely.
2. **A rebasing share token would break note accounting outright.** The Pool
   custodies the actual share ERC-20 while notes record unit counts. If the token
   rebases, the Pool's balance and the sum of outstanding note values diverge, and
   redemptions either over-pay or run out. The codebase already treats this as an
   invariant: `src/adaptors/lido/LidoAdaptor.sol:38` wraps stETH into wstETH
   specifically because *"stETH is a rebasing token, wstETH is non-rebasing ...
   required for easier integration with Veilnyx as it doesn't have to account for
   rebasing tokens."*

**The share token must therefore be non-rebasing, always**, and NAV must be allowed
to sit wherever it lands. Solve the presentation problem in the UI instead: show
performance since the holder's **own entry** rather than absolute NAV, and state
recovery-to-breakeven explicitly — from 0.3694 that is a 171% gain.

#### Insurance buffer: **no separate fund** — the entry fee already is one

- **Scale mismatch.** A liquidation costs ~63% of equity (§4.3). A fee-funded
  buffer at any plausible size — 1–2% of TVL after months of accrual — turns a 63%
  loss into a 62% loss. That is not insurance, it is a rounding error that costs
  real revenue while making the product look safer than it is.
- **Cross-subsidy.** A shared buffer re-couples vaults that §3.2 deliberately
  separated into independent Core accounts. `BTC-LONG` holders would be
  underwriting `ETH-SHORT`.
- **Governance.** Who authorises a payout, on what evidence, and how is that not
  discretion of exactly the kind §6.3 is trying to avoid?

The conservative entry fee in §6.1 Option A **already accrues to NAV**, building a
cushion inside each vault, owned by that vault's holders, with no separate pot, no
cross-subsidy and no payout decision. That is the buffer, and it belongs to the
right people.

Spend the remaining design effort on **not being liquidated** rather than on
compensating for it:

- **De-risk band.** When equity falls below a multiple of maintenance margin — 1.5×
  is a reasonable starting point — reduce leverage instead of holding target. This
  converts a 63% catastrophic loss into a smaller realised one.
- The C3 margin top-up from the EVM-side buffer is the same instinct and is already
  planned.
- **Disclose the consequence.** A vault that de-levers in a drawdown is no longer
  tracking its headline leverage, and will not fully participate in a recovery.
  Every leveraged ETF has this property; say it up front rather than letting
  holders discover it.

A vault that de-levers at 1.5× maintenance is essentially never liquidated except
on a gap — and a gap is precisely what a small insurance fund could not have
covered either.

### 6.3 What exactly can Veilnyx admin do?

The strategy is a rule, so there is no trading discretion to trust. But Veilnyx
owns the contracts and runs the keeper. Keeper failure is an availability risk —
it cannot steal, but it can let a vault drift off target and liquidate at a level
nobody chose. Contract ownership is a genuine trust vector. Scope it and say so
plainly; "non-custodial" is not a fair description of a vault whose admin can
change the strategy.

### 6.4 NAV manipulation

Shares mint and redeem against a mark price. In a thin market, depressing the mark
to deposit cheaply and redeeming at a corrected NAV drains existing holders. Needs
TWAP, deviation bounds, and possibly a redemption delay. Standard vault attack;
must be closed before any real money.

### 6.5 Which vaults launch, and at what leverage?

§4.5 argues strongly against 10x. Recommend starting with a single 2x vault,
proving the loop end to end, and expanding only afterwards. Each additional vault
multiplies contracts, Core accounts, share tokens, price feeds, buffers and keeper
loops — a 3-asset × 2-direction × 3-tier matrix is 18 of everything.

### 6.6 Positioning

This makes Veilnyx an **asset manager** running leveraged funds. That is a
different risk surface from operating neutral privacy infrastructure, and probably
a different conversation with counsel. Cheaper to settle now than after 18 vaults
exist.

---

## 7. Validation plan

Each step gates the next.

1. **Share accounting in isolation** — unit tests against `docs/vault_shares_sim.py`
   as the oracle. Deposit, deposit-at-higher-NAV, partial redeem, full redeem.
   Assert explicitly that shares are struck at **pre-deposit** NAV (§3.4).
2. **NAV composition** — with USDC deliberately stranded mid-bridge, confirm NAV
   counts Core equity **plus** idle HyperEVM balance. A NAV that reads only `0x80f`
   will pass every other test and still misprice every deposit.
3. **One vault, testnet, no shielding** — activate its Core account, bridge, open,
   rebalance, close, with NAV read from precompiles at each step. Confirm the whole
   §3.4 pipeline including the asynchronous steps.
4. **Buffer and leverage** — confirm the Core account's real leverage matches
   expectations given the EVM-side buffer, and that the margin top-up rule fires
   before maintenance (C3).
5. **Through the pool** — a full `CALL_ADAPTOR` deposit producing a share note,
   then a redeem spending it. Confirms the Morpho-shaped path holds end to end.
6. **Adversarial NAV** — attempt the §6.4 manipulation against the deployed bounds.
   If it works, the vault is not launchable.
7. **De-risk band** — walk a testnet vault down toward maintenance and confirm it
   de-levers at the configured multiple and tops margin up from the buffer (A8),
   *without* reaching liquidation. This is the primary loss-limiting mechanism, so
   it needs a test that proves it fires, not just that it compiles.
8. **Liquidation and restart drill** — with the de-risk band disabled, deliberately
   liquidate a testnet vault, then confirm the full §6.2 sequence: deposits freeze,
   redemptions stay open at residual NAV, notes minted before the liquidation still
   redeem, and a fresh deposit after an operator resume prices at post-liquidation
   NAV per §4.4.

Steps 2 and 8 are the ones that will be tempting to skip and must not be. Step 2
because it fails silently, and step 8 because it requires deliberately destroying
money on testnet.

---

## 8. Out of scope

- Discretionary strategies of any kind. The moment a human picks direction, this
  becomes a managed fund and the trust argument in §6.3 collapses.
- Leverage above 10x — the exchange cap cannot be raised from a contract (§3.1).
- Changing `Pool` to support multiple adaptor handlers. §3.2's per-strategy
  contract pattern avoids needing it; if a design starts requiring it, re-evaluate,
  because it forfeits the no-protocol-change property that makes this cheap.
- Sub-account-based isolation — impossible from a contract, see §3.1.
- Mainnet. The current HyperEVM work sits on a branch carrying locally generated
  single-contribution circuit keys rather than ceremony keys, so a real deployment
  needs that key decision resolved first.

  ## 9. Shiven ques
  - **Share allotment based on pre-NAV:**
    - The allotment should happen when the deposit D has been bridged to the CORE (spot bal), ready to be moved to perp bal.
As bridging is aysnc, alloting SHAREs on pre-NAV (before the bridge, synchronously) is risky. Equity can change due to price movements of underlying asset, hence altering share allotment, with no way to correct it once committed based on pre-NAV price.
  - concerned about point 4.2
