# PerpVault external review brief

## Scope

Four contracts, ~1,300 lines, plus one keeper script:

| file | role |
|---|---|
| `src/adaptors/hyperliquid/PerpVault.sol` | single-strategy leveraged perp vault; shares, claims, bridge, rebalance |
| `src/adaptors/hyperliquid/PerpVaultAdaptor.sol` | shielded-pool adaptor: DEPOSIT / REDEEM / CLAIM |
| `src/adaptors/hyperliquid/ClaimToken.sol` | vault-owned receipt, denominated in SHARES (18dp) |
| `src/adaptors/hyperliquid/IHyperCore.sol` | precompile bindings + CoreWriter encoding |
| `script/hyperliquid/keeper/keeper.mjs` | off-chain sequencer (informational; trust model assumes it can be hostile) |

Out of scope: the Veilnyx Pool, verifiers, and circuits (separately reviewed);
Morpho and other adaptors.

## System model — the four facts everything rests on

1. **Two ledgers.** Asset lives in five places: HyperEVM ERC20 balance,
   in-flight inbound bridge, Core spot, Core perp equity, in-flight outbound
   bridge. `totalAssets()` must equal their sum minus `claimPot` at all times.
2. **CoreWriter actions are asynchronous.** Orders are delayed seconds and
   REJECTED SILENTLY (>5 sig figs, <$10 notional, insufficient margin). Class
   transfers execute after the EVM transaction. Nothing may read its own
   action's effect.
3. **Reads and writes use different scales.** Reads are per-asset
   (szDecimals); writes are uniform 1e8; perp USD is 1e6; the spot bridge is
   x100. Every observed historical bug in this codebase was a scale or
   asynchrony bug.
4. **Claims are share-denominated.** A queued exit stays exposed to NAV until
   settlement strikes it from the realised unwind. Escrowed, never burned
   early; settlement is NAV-neutral by construction.

## What the review should try hardest to break

- The derived bridge measurements (`pendingBridge`, `pendingWithdraw`) under
  interleavings with idle/spot movement — three real bugs lived here (C-1 and
  two invariant-suite finds); the fix pattern is rebase-on-move plus
  serialisation (`BridgeBusy`). Adversarial question: is there any remaining
  sequence where reported gross diverges from physical asset?
- Queue fairness: `redeem()` runs `fundClaims()` first (C-2). Can a fresh
  redeemer or depositor still front-run value from queued exiters?
- The claim pot: bounded by idle at settlement and excluded from
  `postMargin`. Can it be made unpayable?
- NAV gates: mark-vs-index deviation blocks pricing but NOT escrow-only exit.
  Is any priced path reachable under a pushed mark?
- The exchange-minimum widening (`TrimWidened`, ceil-sized): can a queue stall?

## Known and accepted behaviours (do not report)

- Claim tranches BLEND in the pot (documented on `claim()`); per-epoch rates
  conflict with fungible bearer notes.
- `maintenanceMargin()` is exact only in the lowest margin tier; the deposit
  cap keeps positions inside it.
- Core spot has no recovery path if the token's EVM link is broken; deploy
  script asserts the link, testnet drills override loudly.
- Owner is trusted (parameter setters, freeze, keeper assignment). Keeper is
  semi-trusted: bounded by slippage/oracle gates, margin floor, and the pot
  exclusion; it can degrade performance but should not be able to steal.

## Verification evidence available to the reviewer

- 57 unit/integration tests; 4 invariants clean over 24,576 randomized calls
  each (`test/adaptors/PerpVaultInvariant.t.sol` — ghost-accounting handler).
- Real-proof e2e through the Pool (`PerpVaultFixture.t.sol`).
- Three testnet drills against live HyperCore, including a keeper-driven full
  lifecycle on final bytecode: deposit -> bridge -> 2x BTC position -> 30%
  queued exit -> proportional trim (real fills) -> sub-$10 tail widened to a
  real $10.76 fill -> margin walked home -> claims settled and paid.
- `PERP_VAULT_PRODUCTION_PLAN.md` holds the full audit history: every finding,
  every fix, and the PoC that proved it.

## Bug history (severity, one line each) — what "done" has meant here

C-1 phantom NAV (withdraw baseline); C-2 queue jumping; postMargin swallowed
credits into a fresh baseline; postMargin could bridge the claim pot; baseline
read ignored the in-tx class transfer; exit-price fixing at request (share
redenomination); adaptor stranded CLAIM at the handler; silent sub-$10 and
sub-minimum-after-flooring orders; keeper drift measured against the wrong
equity; keeper nonce races; keeper band starving the settlement tail.
