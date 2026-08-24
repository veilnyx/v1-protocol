# Screened venue with private funding: preparation plan

Status: PREPARATION — nothing here is committed roadmap. This document exists
so that when the team returns to Hyperliquid's "star" allowlisting, the
verified facts, the product shape, and the open questions are already written
down. Observed and verified on testnet 2026-08; mainnet parameters unknown.

---

## 1. What a star dex is (verified, not assumed)

HIP-3 lets a builder deploy their own perp dex on HyperCore: their own markets,
margin tables, oracle, and a share of trading fees. "Stars" add deployer-managed
address allowlisting on top. Decoded from the ktob ("BTC Star DEX") testnet
transactions:

```
register market   perpDeploy.registerAsset2
                  { assetRequest: { coin: "ktob:BTC", szDecimals, oraclePx,
                                    marginTableId, marginMode },
                    dex: "ktob",
                    schema: { fullName, collateralToken: 0,   <- USDC
                              oracleUpdater: null } }         <- defaults to deployer
activate star     perpDeploy.star { dex, operation: "activate" }
approve trader    perpDeploy.star { dex, operation: { modifyApprovals: [[addr, true]] } }
halt / unhalt     perpDeploy.haltTrading { coin, isHalted }
```

Observed behaviour: non-allowlisted addresses can fund accounts and submit
reduce-only orders but cannot open (their order tx fails); allowlisted
addresses trade normally. Allowlist cap on testnet: 10,000 addresses.

Two integration facts that will bite anyone who skips them:

- **Star-dex markets use OFFSET asset ids.** The observed order targets asset
  `2500000`, not a small index like main-dex BTC = 3. Every precompile and
  CoreWriter call in our stack assumes main-dex indexing (`perpDex = 0` in
  `marginSummary`); a star-dex integration must plumb the dex parameter and the
  id offset end to end.
- **The deployer runs the oracle** (`oracleUpdater` defaults to the deployer).
  Deploying a venue means operating a price feed with liveness and manipulation
  duties. This is an operational product surface, not a config field.

## 2. The product, stated precisely

> A perp venue where every participant is provably screened, and every
> participant's funding is private.

Veilnyx already operates the screening half (Screener contract, ASP machinery)
and the privacy half (shielded funding). A star dex composes them:
the allowlist is driven by screening attestations, funding arrives through the
existing private rails, and Veilnyx earns the HIP-3 deployer fee share.
The reduce-only carve-out gives the compliance story its missing piece: an
address de-listed after a screening change can always close and leave —
gated venue, never trapped funds.

Two variants, in ascending ambition:

- **V1 — screened public addresses.** Pure compliance venue: users screen,
  their trading address is allowlisted. No burner machinery. Simplest possible
  proof of the venue product.
- **V2 — screened burners.** Funding privacy AND a screened set: the burner is
  allowlisted after its screening attestation, so "who trades here" is
  answerable as a set while "which user is which burner" stays hidden.
  Only viable with the batching rule below.

## 3. Threat model deltas (beyond PRIVATE_POSITIONS_PLAN section 7)

1. **Approval-timing correlation.** `modifyApprovals` is public and
   timestamped. Rule: approvals batch on a fixed schedule (e.g. daily), never
   per-signup, so approval time carries no information about funding time.
2. **Deployer key concentration.** One key controls the allowlist, the oracle
   updater, and halts. It is a compliance actor, an operator, and a market
   authority at once — custody and governance for it must be designed like the
   vault owner key, not like a keeper key.
3. **Oracle duty.** A deployer-operated oracle on our own venue is a
   manipulation target pointed at our own users. Either mirror the main dex's
   BTC oracle mechanically or do not list the market.
4. **Set size is the anonymity set.** A venue of N screened burners hides each
   burner among N, not among all of Hyperliquid. The cap (10k observed) bounds
   both capacity and privacy. State this in any user-facing claim.

## 4. What must be verified before any build decision

| # | question | how |
|---|---|---|
| 1 | Mainnet HIP-3 stake requirement and star availability | docs / mainnet observation; the number determines whether this is even affordable |
| 2 | Mainnet allowlist cap | as above |
| 3 | Full `perpDeploy` schema (registerAsset2 fields, margin tables, fee share setting) | replicate the ktob flow on testnet with our own throwaway dex |
| 4 | Precompile behaviour for star dexes (`perpDex` parameter, asset-id offsets, position/margin reads) | testnet probe against the ktob dex or our own |
| 5 | Whether contracts (not just EOAs) can be allowlisted and trade a star dex | probe with a minimal contract, like the SpotProbe did for spotSend |
| 6 | SDK support for `perpDeploy` actions | inspect hyperliquid-python-sdk / raw-sign if absent |
| 7 | Fee-share mechanics: how the deployer share is set and collected | testnet observation |

Items 3–5 are a day of testnet work reusing the drill tooling. Items 1–2 and 7
are reading, not engineering.

## 5. Workstreams, if greenlit

| ws | scope | size |
|---|---|---|
| A | Testnet replication: deploy own star dex, full lifecycle drill (register, activate, approve, trade, halt, de-approve, reduce-only exit) | S |
| B | Allowlist manager: screening attestation -> batched modifyApprovals, on the fixed schedule | M |
| C | Oracle operation: mirrored feed for listed markets, monitoring, halt runbook | M-L |
| D | Funding rails: reuse burner funding flow (V2) or plain deposit flow (V1) | S given existing work |
| E | Venue UI: market page over the star dex, gated by screening status | M |
| F | Liquidity: maker arrangement for the venue's books — a business problem before a technical one | ? |

## 6. Open decisions

- V1 (screened publics) first, or straight to V2 (screened burners)?
- Which markets, and is a mirrored-oracle BTC market acceptable at launch?
- Deployer key custody and the governance story for de-listing an address.
- Fee-share split between Veilnyx treasury and any liquidity partner.
- Whether the venue claim is "screened set" (weak, honest) or per-address
  attestations (stronger, more machinery).

## 7. Relationship to the products in flight

None. The PerpVault trades the main dex and is unaffected. The private
positions product must NOT be pointed at a star dex (PRIVATE_POSITIONS_PLAN
section 8). This is a third product that shares infrastructure with both.
