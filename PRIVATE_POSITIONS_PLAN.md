# Private positions on Hyperliquid: development plan

Status: **plan only, nothing implemented.**
Companion to `HYPERLIQUID_HANDOVER.md`, and it supersedes that document's section 9.

This plan covers private perp positions on Hyperliquid via **self-custodial burner accounts**, not via
a pool-held position. Section 2 records why the pool-held designs were ruled out, with the evidence,
so the decision does not get relitigated from the same starting assumptions.

---

## 1. What is being built

A user opens a perp position on Hyperliquid, funded out of Veilnyx, without the position being
linkable to their main identity.

The mechanism: the user withdraws from the shielded pool into a **freshly generated, self-custodial
burner account**, and that burner deposits to HyperCore and trades. Veilnyx provides the key
generation, the funding flow and the trading UI. The wallet-provides-a-perps-frontend shape, as
MetaMask and Phantom already do it.

State the claim precisely, internally and externally:

> **This is private funding of a public position. It is not a private position.**

The position is openly the burner's — size, direction, entry, leverage and liquidation price are
public on Hyperliquid's API and leaderboards, permanently, attached to that address. What is hidden
is the link between the burner and the user. Privacy therefore rests **entirely** on the withdrawal
being unlinkable, and the anonymity set is the shielded pool's at that amount and time. Nothing more.

The practical consequence is that most of the real engineering in this project is **decorrelation,
not integration**. Section 7 is the substance of the product; sections 5 and 6 are plumbing.

---

## 2. Why this shape, and what was ruled out

`HYPERLIQUID_HANDOVER.md` §9 poses the architecture as hinging on *"can a contract create and control
HyperCore sub-accounts?"* and branches on yes/no. Both branches are dead. The evidence:

### 2.1 A contract cannot create or control sub-accounts

The CoreWriter action table (official docs, verified in full) is ids **1–13 and 15–17; id 14 is
absent**:

| | | | |
|---|---|---|---|
| 1 limit order | 2 vault transfer | 3 token delegate | 4 staking deposit |
| 5 staking withdraw | 6 spot send | 7 USD class transfer | 8 finalize EVM contract |
| 9 add API wallet | 10 cancel by oid | 11 cancel by cloid | 12 approve builder fee |
| 13 send asset | 15 borrow/lend | 16 set abstraction | 17 outcome operation |

There is no sub-account action. `createSubAccount` is an **exchange-endpoint** action, msgpack-hashed
and signed by the master key over the `Agent` typed struct on chain id 1337. A contract has no key,
and no EIP-1271 path on that endpoint is documented. It is additionally volume-gated — 10
sub-accounts after $100k volume, 50 maximum — so it could never be per-user regardless.

### 2.2 A contract cannot set isolated margin either

The same gap: **no CoreWriter action updates leverage or margin mode.** Action 1's fields are
`(asset, isBuy, limitPx, sz, reduceOnly, encodedTif, cloid)` — no margin-mode field, so it cannot be
selected per order either. Adding or removing margin from an open isolated position is likewise an L1
action. Verified on chain 998: precompile `0x800` returns 160 bytes decoding to
`Position{int64 szi, int64 entryNtl, int64 isolatedRawUsd, uint32 leverage, bool isIsolated}`, and a
fresh account reads `leverage=10, isIsolated=false`. A contract's Core account is stuck at cross
margin, default 10x.

### 2.3 Isolated margin would not have delivered per-user isolation anyway

Isolated margin is scoped **per (account, asset)**, not per position. Hyperliquid's margining docs:
*"Liquidations in that asset do not affect other isolated positions or cross positions."* It walls off
assets from each other **inside one account**. One account cannot hold two positions in the same
asset. Ten users long BTC through one pool account still net into **one** BTC position with **one**
liquidation price. §9's stated goal — one user's liquidation cannot affect another's — is not what
isolated margin provides.

### 2.4 The only contract-side escape hatch is a trusted signer

CoreWriter action 9, `Add API wallet(address, string)`, lets a contract authorize an off-chain agent
key, and agents *can* create sub-accounts, set leverage and trade. That agent cannot withdraw, so the
blast radius is bounded, but it can still trade the pool's account into the ground. It converts a
trustless design into an operator-trusted one, and still caps out at 50 sub-accounts.

### 2.5 Therefore

Every capability that is blocked for a contract is available to an EOA, because an EOA has a key.
The burner design does not work around the CoreWriter gaps — it makes them irrelevant by not using
CoreWriter at all. It also needs **no contract changes, no circuit changes, and adds no audit
surface**, which the pooled-vault alternative could not claim.

Recorded for completeness: the pooled **shielded perp vault** (notes as pro-rata share tokens over one
aggregate position, structurally identical to the existing Morpho vault-share adaptor) remains
technically viable and trustless. It is not being built because it takes away the thing users want —
choosing their own size, entry and leverage — in exchange for hiding position details inside an
aggregate. It is a genuinely different product, and can be revisited on its own merits later.

---

## 3. Architecture

Nothing here executes inside a Veilnyx contract. The whole flow is SDK and UI over existing
primitives.

```
  User's shielded balance
        │
        │  (1) Shielded WITHDRAW, relayed
        │      target   = burner EOA (freshly generated)
        │      pubAssets = [ USDC, native HYPE ]     <- both in ONE transaction
        │      fee      = paid in-asset via Paymaster
        ▼
  Burner EOA on HyperEVM  ── has gas and margin, has touched nothing else ──
        │
        │  (2) ERC20 transfer to the token's Core system address
        │      0x20..00 ‖ tokenIndex   (big-endian token index)
        ▼
  Burner's HyperCore spot balance      (minus 1 quote-token activation fee)
        │
        │  (3) usdClassTransfer(ntl, toPerp=true)   — spot → perp margin
        ▼
  Burner's perp account
        │
        │  (4) Normal signed L1 actions: updateLeverage (isolated!), order, cancel, close
        ▼
  Position — public, owned by the burner, unlinked to the user

  ... return trip is (4)→(3)→(2) reversed, then a public deposit back into Veilnyx.
```

Step 4 is where the burner design pays off: `updateLeverage(asset, isCross=false, leverage)` is
available, so each position gets **genuine isolated margin on its own account**. Per-user isolation,
which was unreachable in every pool-held design, is free here.

---

## 4. What already works, and what is missing

### Verified working (read from code / chain, not assumed)

- **Arbitrary withdrawal recipient.** `params.target = address(bytes20(stx.targetData))` in
  `_copyParamsToMemory` (`src/libraries/ShieldedTransactionLogic.sol:822`). A burner address is just a
  target. No change needed.
- **Multi-asset withdrawal to one recipient.** `_transferPubAssets`
  (`src/libraries/ShieldedTransactionLogic.sol:673-717`) loops every `pubAssets` entry to the same
  `to`, and unwraps the `nativeWToken` entry to native via `wToken_.withdraw` +
  `Address.sendValue`. **One withdrawal delivers USDC and native gas atomically.** This is the single
  most important property in the whole design — see §7.1.
- **Relaying.** `Paymaster.sol` (ERC-4337, `EntryPoint` + Gateway as `sender`, `GAS_ASSET_ID = 65537`)
  plus the packed paymaster address in `feeData` and `_creditPaymasterFee`. The burner never needs
  pre-existing gas to receive its own funding.
- **HyperCore reads from HyperEVM.** Precompiles respond on chain 998: `0x800` position, `0x801` spot
  balance, `0x803` withdrawable, `0x80f` margin summary, `0x809` L1 block, `0x810` `coreUserExists`
  (reads `false` for the deployed pool proxy, consistent with handover §3). Not required for the core
  flow, but available for UI position display without trusting an API.

### Missing

- **`Config` is not deployed on `hyperliquid/testnet-e2e`,** so `nativeWToken` is unset and native
  HYPE cannot be withdrawn. Handover §6 flags this as deliberate for the smoke test. This is
  **configuration, not code** — deploy `Config`, set WHYPE as `nativeWToken`, register it as an active
  asset with a price feed.
- **No burner lifecycle anywhere in the SDK.**
- **No Hyperliquid trading surface in `v1-interface`.**
- The environment blockers in handover §8 (`@veilnyx-sdk/core` missing its `dist/cjs`
  `{"type":"commonjs"}` marker; `getConfigWithDefaults` rejecting a partial service set) are still
  open and will bite anyone doing SDK work here.

### One HyperCore detail to budget for

New Core accounts pay a **one-time 1 quote-token activation fee**, charged to the *recipient* on the
first incoming transfer. The burner bridges X USDC and lands X−1 on Core. Harmless in itself, but it
**breaks round-number denominations**, which directly affects the decorrelation scheme in §7.2 — the
denomination has to be chosen on the Veilnyx side, and the Core-side amount will be off by one.

---

## 5. Workstreams

Sized S/M/L rather than dated. Dependencies noted; `P0` blocks a first internal demo.

### A. Protocol config — `v1-protocol` `[P0, S]`

| | Task |
|---|---|
| A1 | Deploy `Config` on HyperEVM testnet; wire WHYPE as `nativeWToken` via `setNativeWToken`. |
| A2 | Register WHYPE as an active asset with a price feed (needed by `_getUsdValue` / TVL). |
| A3 | Set the protocol version — handover §6 notes `version()` reads 0. |
| A4 | End-to-end test: single `WITHDRAW` carrying USDC **and** native HYPE to one fresh address. This is the load-bearing assumption; prove it on chain before anything else is built on it. |
| A5 | Confirm the USDC in use on HyperEVM is **linked** to Core USDC and resolve its token index / system address. An unlinked token cannot be bridged. |

No Solidity changes are anticipated. If A4 surfaces one, that is a finding worth escalating — it
changes the effort profile of the whole project.

### B. Burner lifecycle — `v1-sdk` `[P0, M]`

Depends on A.

| | Task |
|---|---|
| B1 | Burner key generation. **Decide derivation first — see §6.1.** |
| B2 | Encrypted burner storage + export/backup, keyed to the user's Veilnyx account. |
| B3 | Funding builder: compose the multi-asset relayed `WITHDRAW` (USDC + HYPE, denominated per §7.2). |
| B4 | Bridge helper: ERC20 transfer to the Core system address `0x20..00 ‖ tokenIndex`, then CoreWriter-free `usdClassTransfer` **signed by the burner** (spot → perp). |
| B5 | Hyperliquid L1 signing for the burner: msgpack + `Agent` typed struct, chain id 1337. Use the official SDK's scheme; do not hand-roll. |
| B6 | Position lifecycle: `updateLeverage` (isolated), order, cancel, close, and the return trip. |
| B7 | Return path: Core → EVM spot send → public deposit back into Veilnyx. |

### C. Trading UI — `v1-interface` (Next.js) `[P0 for a minimal surface, L for a real one]`

Depends on B.

| | Task |
|---|---|
| C1 | Burner management screen: create, list, balance, export, and an explicit "this key holds real money" state. |
| C2 | Funding flow with **denomination and delay presented as product, not buried** — see §7.2. |
| C3 | Minimal trading surface: market/limit, size, leverage, isolated margin default, close. |
| C4 | Position view. Prefer the `0x800` / `0x80f` precompiles over the public API where practical, so the UI does not leak which positions a user is watching. |
| C5 | Privacy state indicator: warn on burner reuse, on funding from a non-Veilnyx source, on a linkable amount. |

### D. Decorrelation — cross-cutting `[P0, M]`

Depends on nothing; **should be designed before B3 and C2 are written**, because it constrains both.
See §7. This is the workstream that determines whether the product is actually private, and it is the
one most likely to be deferred by accident.

### E. Documentation `[P1, S]`

| | Task |
|---|---|
| E1 | Amend `HYPERLIQUID_HANDOVER.md` §9 — it currently sends the next reader down the sub-account path that §2 above closes off. Replace with a pointer here. |
| E2 | User-facing writeup of the privacy model that says plainly what is and is not hidden. |

---

## 6. Open decisions — answer before building

### 6.1 Burner key derivation: deterministic or random?

The most consequential decision in the project, and it is a genuine trade-off.

- **Deterministic** (derived from the user's Veilnyx spending key + an index): burners are
  recoverable from the seed the user already has. No new backup burden. **But** anyone who learns the
  derivation path and one burner can potentially enumerate the rest, and a compromised seed exposes
  every position retroactively.
- **Random**: no cross-burner linkage even on seed compromise. **But** every burner is an independent
  backup obligation, and a lost key is a lost position with no recovery.

A hybrid — deterministic derivation with a per-burner random salt stored encrypted — gets most of
both, at the cost of the salt store becoming a dependency.

### 6.2 What is the return path's privacy story?

Closing a position returns funds to the burner, which then deposits publicly into Veilnyx. That
deposit is *supposed* to be public. But the amount is the burner's PnL, and it is unlikely to be a
round denomination. Options: return to the same shielded account and accept the amount leak; route
through an intermediate hop; or hold and batch. **Unresolved, and it is the weakest part of the
design.**

### 6.3 Who runs the relayer, and what does it see?

The relayer submits the funding withdrawal and therefore learns (burner address, amount, time) even
though it does not learn the user. A malicious or compelled relayer holds one half of the correlation
directly. Existing Paymaster/Gateway infrastructure presumably has an answer; it needs to be written
down for this flow specifically.

### 6.4 Custody posture

Are these burners Veilnyx's responsibility or the user's? This is a product and, plausibly, a legal
question, not a technical one. It should be answered before C1 is designed, because it determines
whether the UI is a wallet or a convenience.

### 6.5 Testnet vs mainnet target

Handover §6 is explicit that `hyperliquid/testnet-e2e` is not mergeable to `stage` — locally
generated single-contribution keys, regenerated fixtures. This work can be prototyped there, but the
key decision in handover §7.2 has to be resolved before anything ships.

---

## 7. Threat model and decorrelation rules

The whole privacy claim reduces to: **can an observer link a Veilnyx withdrawal to a burner?** These
are the ways they can, in rough order of severity.

### 7.1 Gas funding — solved, keep it solved

A freshly generated EOA has no gas. If it is funded from the user's main wallet, the design is
over — total, immediate deanonymization, and it is the mistake this category of product makes most
often.

The multi-asset withdrawal in §4 closes this: USDC and native HYPE arrive in the **same** shielded
withdrawal, submitted by a relayer, so the burner touches nothing before it is funded. **This must be
enforced in the SDK, not left to the UI.** Any code path that lets a burner receive gas from anywhere
else is a critical bug, and should be treated as one.

### 7.2 Amount and timing correlation — the main residual risk

An observer sees a Veilnyx withdrawal of X at time T, and address A activating on Core at T+δ with
approximately X. If X is distinctive, that is the link. Mitigations, all of which are product
constraints rather than code:

- **Fixed denominations.** Users fund in standard sizes, not arbitrary amounts. Note §4: the 1
  quote-token activation fee means the Core-side figure is X−1, so denominate on the Veilnyx side.
- **Randomized delay** between withdrawal and the Core deposit. Directly trades UX for privacy and
  needs a product decision on the range.
- **Never fund two burners from one withdrawal**, and never top up an existing burner from a second
  withdrawal — both create clusters.
- Size the anonymity set honestly: at low pool volume, denominations do not help much. The UI should
  be able to say so.

### 7.3 Burner reuse and cross-position fingerprinting

One burner per position, always. Beyond that, the positions themselves are public and permanent, so
consistent trading style, sizing habits or timing across several burners will cluster them. Nothing
in the design prevents this; the UI can only warn. Worth stating in E2 rather than pretending
otherwise.

### 7.4 The position is public — this is not a bug, but it must not be oversold

Handover §9's closing note applies here at full strength: at low volume a position is a near unique
fingerprint. In this design that is not a residual leak to be engineered away, it is the explicit
model. Sales and docs must not describe this as "private positions" without qualification.

### 7.5 Relayer trust

See §6.3.

---

## 8. Validation plan

In order. Each gates the next.

1. **A4** — one withdrawal, two assets, one fresh recipient, on testnet. Confirms the load-bearing
   assumption before any SDK work.
2. **Burner cold start** — a burner that has *never* received anything from any source other than the
   Veilnyx withdrawal successfully bridges to Core, activates, and opens an isolated position. Confirms
   §7.1 end to end.
3. **Isolated margin** — confirm via precompile `0x800` that the burner's position reads
   `isIsolated=true` and the leverage it was set to. This is the concrete proof that the burner design
   delivers what no pool-held design could.
4. **Full round trip** — open, close, return to Veilnyx, with the shielded balance reconciling.
5. **Adversarial pass** — take the chain data alone, from the perspective of an observer with no
   inside knowledge, and attempt to link the burner to the funding withdrawal. Do this before shipping,
   not after. If it is easy, §7.2 is not solved and the product claim is wrong.

Step 5 is the real acceptance test. Steps 1–4 only prove it functions.

---

## 9. Explicitly out of scope

- Any Veilnyx contract change, any circuit change, any new adaptor. If the design starts requiring
  one, stop and re-evaluate — the main argument for this shape is that it needs none.
- CoreWriter integration of any kind. The burner signs its own L1 actions.
- The pooled shielded perp vault (§2.5). Viable, different product, separate decision.
- Any operator-signed / API-wallet design (§2.4).
- Spot trading, HIP-3 dexes, vaults, staking.
- Mainnet deployment, pending handover §7.2 on keys.

---

## 8. Stars / HIP-3 allowlisting — observed on testnet, 2026-08

Hyperliquid testnet now lets a HIP-3 (builder-deployed) perp dex be
address-allowlisted for trading: only deployer-approved addresses can OPEN
positions; everyone can still fund and submit reduce-only orders, so nobody can
be trapped in a position. Allowlist cap observed: 10k addresses. Verified
against the ktob "BTC Star DEX" transactions — the actions are `perpDeploy`
with `star: {dex, operation: "activate" | {modifyApprovals: [[addr, bool]]}}`.

**Do NOT use this for burners.** Every `modifyApprovals` is a public deployer
transaction naming the burner, timestamped. Approval time correlates with
burner creation and pool-withdrawal time — exactly the correlation section 7
exists to destroy — and it concentrates burners into a labelled set instead of
letting them hide among all of Hyperliquid's fresh addresses. Burners gain
nothing from it: they already trade the main dex's full books.

**Where it IS interesting:** the allowlist is a compliance primitive, and
Veilnyx owns the other half (Screener / ASP). A screened venue with private
funding is a distinct third product; see `docs/STAR_DEX_SCREENED_VENUE_PLAN.md`.
If that is built, the timing leak has a known fix: batch approvals on a fixed
schedule so approval time decorrelates from funding time — the same
hold-and-batch shape as the 6.2 return path.

