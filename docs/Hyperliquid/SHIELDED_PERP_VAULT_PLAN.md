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
- **Creating or controlling sub-accounts.** `createSubAccount` is an
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

### 4.3 Liquidation is closer than it looks

```
Opened at 100,000; liquidation price 94,737, only 5.26% away.
```

A 10x long is roughly **5% from ruin, not 10%**, once the maintenance requirement
is counted. And every share note against that vault goes to approximately zero
simultaneously. There is no partial survivor.

### 4.4 Volatility decay: price flat, vault down 32%

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

---

## 5. Workstreams

Sized S/M/L. `P0` blocks a first internal demo.

### A. Vault contract `[P0, L]`

| | Task |
|---|---|
| A1 | `PerpVault` contract: own Core account, share ERC20 (mint/burn), NAV computation, deposit/redeem. |
| A2 | NAV from precompiles — `0x800` position, `0x80f` margin summary, `0x806` mark price — with staleness and sanity bounds. |
| A3 | Bridge in/out per §3.3: ERC20 to the Core system address, then `usdClassTransfer` spot → perp. |
| A4 | CoreWriter order construction: version byte `0x01`, 3-byte big-endian action id, ABI-encoded payload. Action 1 for orders, 10/11 to cancel. |
| A5 | Rebalance logic with banding, and the entry-fee mechanism from §4.2. |
| A6 | Liquidation handling: detect, halt mint/redeem, define note settlement. **Design decision, see §6.3.** |
| A7 | Admin surface: pause, parameter bounds, and an explicit statement of what admin can and cannot do. |

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
| C3 | Redemption liquidity: buffer sizing, or a claim-note path if a buffer proves insufficient. Closing a position to fund a redemption is subject to the few-second order delay in §3.3. |
| C4 | Monitoring: NAV, effective leverage, distance to liquidation, per vault. |

### D. SDK and UI `[P1, M]`

Deposit/redeem flows, share-note display, and — non-negotiable — decay and
liquidation disclosure at the point of deposit, not buried in documentation.

### E. Simulation `[done, extend as needed]`

`docs/vault_shares_sim.py` covers share accounting, the entry externality,
liquidation and decay. Not modelled yet: funding payments, the order delay,
partial fills, redemption slippage beyond the taker fee, and oracle/mark
divergence. Extend before launch.

---

## 6. Open decisions

### 6.1 How is the entry externality charged?

§4.2 shows a depositor imposing 3.86% on an existing holder. Options: a fixed
entry fee, a fee scaled to the rebalance size, batched deposits at fixed times, or
accepting socialisation and disclosing it. **Unresolved and blocking** — it
changes the vault contract's core accounting.

### 6.2 Shares are priced at a NAV that predates settlement

The share count is committed synchronously in the EVM transaction —
`_handleAdaptorCall` mints `Poseidon(shareAssetId, refundAddress, value)` from the
adaptor's return value — but the deposit only reaches Core margin afterwards. So
shares are struck at `NAV₁ = E₁/S` while the pool they actually join is worth `E₂`.

**This is the one place the Morpho analogy in §2 fails.**
`MorphoVaultAdaptor.sol:84` reads `shares = morpho.deposit(inValue, address(this))` —
the share count is the return value of the very call that moves the assets, so no
window exists. Across HyperEVM and HyperCore one always does, and no amount of
contract design removes it.

Nothing reconciles the difference. There is no error term and no revert; it is
absorbed silently as dilution:

```
Bob's gain = Alice's loss = ΔE · D/(E₁ + D),           ΔE = E₂ − E₁
as a fraction of existing equity:  L × (ΔP/P) × D/(E₁ + D)
```

On §4.1's own numbers (`E₁` 11,946, `D` 12,000, leverage 8.5), a **0.1% BTC move**
inside the window transfers **0.43% of Alice's equity** to Bob; at target 10x with
`D ≈ E₁` it is 0.5%. §4.2's externality was 3.86% across an entire price path — this
is comparable from a single tick, and it recurs on every deposit.

It is also an option rather than noise. The outcome is symmetric — on a fall the
depositor overpays — but the depositor picks the entry and the window follows
mechanically: deposit into upward momentum, skip otherwise. Classic mutual-fund late
trading, and strictly easier to run than §6.5, which needs both a thin market and a
willingness to push the mark.

**Distinct from §6.1 and not fixed by it.** §6.1 is the cost of the rebalance trade;
this is the staleness of the price the shares are struck at. Both are live and they
compound.

Options:

- **Claim note.** Deposit mints a claim on `D` USDC with no NAV read; a second
  `CALL_ADAPTOR` burns it for shares. ERC-7540's async shape, and it preserves the
  no-circuit-change property — the claim is another registered asset, step two an
  ordinary adaptor call. §5 C3 already contemplates claim notes on the redemption
  side. Full mechanics and six caveats in the collapsed section below.
- **Epoch batching.** Also closes it, and fixes §6.1's entry timing at the same time.
  Real UX cost.
- **NAV haircut.** Does *not* close it — it prices the option instead of removing it.
  A floor on the §6.1 entry fee, not a substitute for async minting.

<details>
<summary><b>Claim-note option — full mechanics</b> (rate rule, batch lifecycle, worked example, caveats)</summary>

#### Rate rule

Shares are struck at the NAV **recorded at fulfilment**, never at the NAV prevailing
when the user claims. This is not a detail. A claim priced at claim-time NAV is
strictly worse than the bug it replaces: the holder has a USDC-denominated claim and
picks the conversion moment, so they wait for a drawdown, convert cheap and ride the
recovery — an unbounded look-back option in place of a bounded few-second one.
ERC-7540 fixes the rate at fulfilment for exactly this reason.

Corollary: a late claim costs the holder nothing. Escrowed shares are minted at
fulfilment and counted in supply, so they track NAV for as long as they sit unclaimed.

#### State and the NAV invariant

```
pending   Σ capital of batches not yet fulfilled          (stored)
unlanded  batchTotal[b] − min(spotUsdc() − spotBefore[b], batchTotal[b])   (derived)

E_vault = perp accountValue + Core spot + idle EVM USDC + unlanded
NAV     = (E_vault − pending) / shareToken.totalSupply()
```

`unlanded` must be **derived from the spot delta, never stored and decremented at
fulfilment** — a stored counter double-counts between the moment Core credits spot and
the moment `fulfil` runs, inflating NAV by the batch size. Deriving it also stays
correct through partial credits.

Both terms are exact because the vault snapshots `spotBefore[b]` itself when it
initiates the bridge. Inferring in-flight state from balance comparisons instead does
not work: a concurrently open batch taking deposits masks the outflow.

#### Lifecycle — batches are serialized

A batch may accept deposits at any time. It may not **bridge** until the previous batch
has fulfilled. One batch in flight, ever.

```
        HyperEVM               │ in flight │        HyperCore
───────────────────────────────┼───────────┼────────────────────────────
  deposit ─► vault USDC ─bridge┼─ ·······► ┼─ spot ─usdClass─► perp
  (claim note)   [pending]     │[unlanded] │            [E_settle]
                               │           │
                     fulfil(b): verify spot delta ≥ batchTotal
                                strike nav_b · mint escrow · then move + rebalance
```

Steps, in order:

1. **Open.** Registrar registers `claimAssetId[vault][b]`. Batch accepts deposits.
2. **Deposit** (×N). USDC lands on the vault, EVM-side. `pending += D`. Mint
   `Poseidon(claimAssetId[vault][b], refundAddress, D)`. No NAV read.
3. **Close.** Batch `b` stops accepting; batch `b+1` opens. No value moves.
4. **Bridge.** Snapshot `spotBefore[b]`; ERC20 transfer to the Core system address.
   Capital is now invisible to both chains — `unlanded` covers it.
5. **Credit.** Core credits spot, possibly in parts. `unlanded` falls as `spot` rises.
6. **Fulfil** (permissionless, one transaction). Verify `spot − spotBefore[b] ≥
   batchTotal[b]`; strike `navAtFulfilment[b] = (E_vault − pending)/totalSupply()`,
   write-once; mint `batchTotal[b] / nav_b` shares to escrow; `pending -= batchTotal[b]`.
   Then `usdClassTransfer` to perp, then rebalance.
7. **Claim** (any time, user-initiated). Spend the claim note for
   `D / navAtFulfilment[b]` shares. Timing is inert.

Steps 1–5 leave NAV untouched by construction. Step 6 is value-neutral. Only step 6's
rebalance moves NAV, by its taker fee — that cost is §6.1's, not this section's.

#### Worked example

Vault running at perp equity 22,000, supply 20,000, NAV 1.1000, target 2x.
Batch 1 = Alice 6,000 + Bob 4,000. Batch 2 opens mid-flight and takes Carol and Dave.

```
#  event                          idleEVM  unland    spot     perp  pending      supply      NAV
---------------------------------------------------------------------------------------------------
0  steady state                         0       0       0   22,000        0      20,000   1.1000
1  Alice deposits 6,000  -> B1      6,000       0       0   22,000    6,000      20,000   1.1000
2  Bob   deposits 4,000  -> B1     10,000       0       0   22,000   10,000      20,000   1.1000
3  B1 closes, B2 opens             10,000       0       0   22,000   10,000      20,000   1.1000
4  bridge B1 (spotBefore=0)             0  10,000       0   22,000   10,000      20,000   1.1000
5  Carol deposits 5,000  -> B2      5,000  10,000       0   22,000   15,000      20,000   1.1000
6  Core credits 4,000 of B1         5,000   6,000   4,000   22,000   15,000      20,000   1.1000
7  Core credits final 6,000         5,000       0  10,000   22,000   15,000      20,000   1.1000
8  fulfil(1): strike, mint escrow   5,000       0  10,000   22,000    5,000  29,090.91   1.1000
9  usdClassTransfer lands           5,000       0       0   32,000    5,000  29,090.91   1.1000
10 rebalance fills (fee 9.00)       5,000       0       0   31,991    5,000  29,090.91   1.09969
11 Dave deposits 3,000  -> B2       8,000       0       0   31,991    8,000  29,090.91   1.09969
```

NAV holds at 1.1000 across every step of B1 — including the invisible in-flight window
at #4 and the partial credit at #6 — and moves only at #10, where a real cost is paid.

Step 8 in detail:

```
E_settle = E_vault − pending = 37,000 − 15,000 = 22,000    (excludes B1 and B2 capital)
nav_1    = 22,000 / 20,000  = 1.1000                       navAtFulfilment[1], write-once
escrow   = 10,000 / 1.1000  = 9,090.91 shares minted
```

Claims settle against `nav_1` whenever they arrive:

```
Alice   6,000 / 1.1000 = 5,454.55 shares
Bob     4,000 / 1.1000 = 3,636.36 shares
                         --------
                         9,090.91  = escrow, fully drained
```

**Batch 2** repeats identically, one strike later. B2 could not bridge before #8. It
bridges 8,000, and `fulfil(2)` strikes at the NAV then prevailing:

```
nav_2  = 1.09969                            not 1.1000 — B1's rebalance fee intervened
escrow = 8,000 / 1.09969 = 7,274.80 shares
Carol   5,000 / 1.09969 = 4,546.75
Dave    3,000 / 1.09969 = 2,728.05
```

Note what #10 shows: B1's own rebalance fee is borne 31% by B1 and 69% by the holders
who were already there, because B1's shares exist by then. The externality §6.1 is about
survives this design untouched — as stated, the two are separate problems.

#### Caveats

1. **The batch id can only live in the asset id.** A note is
   `Poseidon(assetId, address, value)`, and `value` must equal a real ERC20 balance the
   pool custodies, so the batch number cannot be packed into it, and a dummy token
   address fails — `_receivePubAssets` does `safeTransferFrom`, which reverts
   `AddressEmptyCode` on a non-contract. A price feed is *not* needed: feedless assets
   contribute 0 to TVL by design (`src/core/Pool.sol:732`) and are only barred from
   being public deposit inputs (`src/core/Pool.sol:709`), which claim and share tokens
   never are. So each batch needs one real, feedless, minimal-proxy ERC20.

2. **Ids are consumed permanently, never recycled.** Recycling is unsound, not merely
   awkward: a stale note at a reused id would convert at the *new* batch's NAV, and
   neither escape works — rejecting late claims expropriates users who were merely
   offline, and the vault cannot settle on their behalf because spending a note requires
   the owner's key and proof. No offchain service can automate the claim without
   custody, so unclaimed notes are a permanent standing population, not an edge case.
   Fresh id per batch, forever; no ring, no deadline. Budget: 65,535 per asset type,
   monotonic and **protocol-wide**, shared with every asset Veilnyx ever registers.
   Daily batching across 18 vaults is ~6,570/yr — roughly a decade. Hourly is ~5 months.

3. **`addAssets` is `onlyOwner`** (`src/core/Pool.sol:128-131`). A per-batch registration
   needs a scoped registrar role granted to the vault — a `Pool` change, so this option
   keeps **no circuit change** but forfeits **no protocol change** (§8). Scope the role
   to CREATE2 clones of one fixed implementation so it can only ever register bytecode
   known in advance. `transact` is `nonReentrant` (`src/core/Pool.sol:364`), so the
   re-entry vector is closed; the residual is griefing via a hostile token.

4. **It weakens the privacy claim in §1.** §1 states there is "no second on-chain event
   to correlate against". Async minting creates precisely that event, and a badly-behaved
   one: the claim's input amount equals the deposit amount `D` exactly, and its assetId
   names the batch. The anonymity set collapses from everyone who ever deposited into the
   vault to co-depositors in the same batch at a similar size — and for a
   single-depositor batch, to nothing. Larger batches widen the set at the cost of
   latency; splitting the claim note before claiming breaks the amount match but costs a
   transaction and relies on user behaviour. **§1 must be reworded if this option is
   taken.**

5. **A tracking gap replaces the wealth transfer.** Between request and fulfilment the
   depositor has no exposure at all. That is correct — they were not capitalised — but
   "deposited at 100k, struck at 102k" will be read as a malfunction. Belongs in §5 D's
   disclosure list alongside decay and liquidation.

6. **A failed bridge must be recoverable.** If Core never credits, `unlanded` never
   clears, `E_vault` over-reports forever, and redemptions drain the vault at an inflated
   NAV — worse than the under-report, which only mis-prices a strike. Needs a timeout:
   after N blocks `cancelBatch(b)` opens, and the claim adaptor gains a second outcome —
   `navAtFulfilment[b] != 0` mints shares, `batchCancelled[b]` returns USDC 1:1,
   otherwise revert. **Open:** the 1:1 refund assumes the funds are recoverable. If they
   are genuinely lost in the bridge, someone eats it — insurance buffer, or a pro-rata
   haircut on that batch. Same shape as §6.3 and unresolved.

</details>

**Unresolved and blocking.** Measure the window first: a shielded transaction does
Groth16 verification plus tree updates, so whether it fits HyperEVM's small-block gas
limit or must wait for a large block decides whether the exposure is ~1s or ~1min.
Nothing measured so far answers that, and the answer determines which mitigation is
proportionate.

### 6.3 What happens to notes when a vault is liquidated?

Equity goes to near zero and every note against it becomes near worthless
simultaneously. Do notes settle at residual NAV? Does the vault halt and
distribute? Is there an insurance buffer? Unanswered, and it is the sharpest
question here.

### 6.4 What exactly can Veilnyx admin do?

The strategy is a rule, so there is no trading discretion to trust. But Veilnyx
owns the contracts and runs the keeper. Keeper failure is an availability risk —
it cannot steal, but it can let a vault drift off target and liquidate at a level
nobody chose. Contract ownership is a genuine trust vector. Scope it and say so
plainly; "non-custodial" is not a fair description of a vault whose admin can
change the strategy.

### 6.5 NAV manipulation

Shares mint and redeem against a mark price. In a thin market, depressing the mark
to deposit cheaply and redeeming at a corrected NAV drains existing holders. Needs
TWAP, deviation bounds, and possibly a redemption delay. Standard vault attack;
must be closed before any real money.

### 6.6 Which vaults launch, and at what leverage?

§4.4 argues strongly against 10x. Recommend starting with a single 2x vault,
proving the loop end to end, and expanding only afterwards. Each additional vault
multiplies contracts, Core accounts, share tokens, price feeds, buffers and keeper
loops — a 3-asset × 2-direction × 3-tier matrix is 18 of everything.

### 6.7 Positioning

This makes Veilnyx an **asset manager** running leveraged funds. That is a
different risk surface from operating neutral privacy infrastructure, and probably
a different conversation with counsel. Cheaper to settle now than after 18 vaults
exist.

---

## 7. Validation plan

Each step gates the next.

1. **Share accounting in isolation** — unit tests against `docs/vault_shares_sim.py`
   as the oracle. Deposit, deposit-at-higher-NAV, partial redeem, full redeem.
2. **One vault, testnet, no shielding** — activate its Core account, bridge, open,
   rebalance, close, with NAV read from precompiles at each step.
3. **Through the pool** — a full `CALL_ADAPTOR` deposit producing a share note,
   then a redeem spending it. Confirms the Morpho-shaped path holds end to end.
4. **Adversarial NAV** — attempt the §6.5 manipulation against the deployed bounds.
   If it works, the vault is not launchable.
5. **Liquidation drill** — deliberately liquidate a testnet vault and confirm §6.3
   behaves as designed, with notes settling the way users were told they would.

Step 5 is the one that will be tempting to skip and must not be.

---

## 8. Out of scope

- Discretionary strategies of any kind. The moment a human picks direction, this
  becomes a managed fund and the trust argument in §6.4 collapses.
- Leverage above 10x — the exchange cap cannot be raised from a contract (§3.1).
- Changing `Pool` to support multiple adaptor handlers. §3.2's per-strategy
  contract pattern avoids needing it; if a design starts requiring it, re-evaluate,
  because it forfeits the no-protocol-change property that makes this cheap.
- Sub-account-based isolation — impossible from a contract, see §3.1.
- Mainnet. The current HyperEVM work sits on a branch carrying locally generated
  single-contribution circuit keys rather than ceremony keys, so a real deployment
  needs that key decision resolved first.
