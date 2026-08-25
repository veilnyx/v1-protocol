# Deployment Configuration Reference — `deployCoreWithAdp.ts`

Every operator-settable value applied by [`script/deployCoreWithAdp.ts`](../script/deployCoreWithAdp.ts),
with its current value, so the set can be reviewed before a mainnet run.

- **Date:** 2026-07-29
- **Branch:** `stage`
- **Sources:** hardcoded literals in `script/deployCoreWithAdp.ts` and `script/erc4337Infra.ts`,
  [`script/config.json`](../script/config.json), [`script/adaptorConfig.json`](../script/adaptorConfig.json)
- **Runnable networks:** `mainnet` (1), `tenderlyMainnetCustomId` (7800), `sepolia` (11155111),
  plus `mainnetFork` (1) — a local anvil mainnet fork for dry runs; see `npm run fork:mainnet`.
  Other chain entries in `config.json` have no `adaptorConfig` counterpart, so `deployAdaptors` throws on them.

---

## 1. Hardcoded in the deploy scripts

Not in any config file. Applies identically to **every** network, including `deployCoreWithAdp:mainnet`.

| Variable | Value | Location | Contract-enforced bound |
|---|---|---|---|
| `tvlLimitUsd` | `5_000e6` = **$5,000** | `deployCoreWithAdp.ts` `configParams` | `type(uint256).max` = uncapped |
| `minDepositUsd` | `2e6` = **$2** | `deployCoreWithAdp.ts` `configParams` | `_validateDepositLimits` |
| `maxDepositUsd` | `200e6` = **$200** | `deployCoreWithAdp.ts` `configParams` | must be ≥ min |
| `priceFeedStalenessThreshold` (Pool) | `ONE_HOUR * 30n` = **108,000 s / 30 h** | `deployCoreWithAdp.ts` `configParams` | ≥ `MIN_PRICE_STALENESS_THRESHOLD` (1 h) |
| `PRICEFEED_STALENESS_THRESHOLD` (Paymaster) | `86400` = **24 h** | `erc4337Infra.ts:5` | ≥ 1 h |
| `PAYMASTER_FUNDING_AMT` | **0.03 ETH** → `depositToEntryPoint` | `erc4337Infra.ts:4` | — |
| Enabled adaptors | uniswap, aave, lido, morpho | `deployAdaptors` | curve, ethena, beefy, oneInch, rocketPool commented out |
| Adaptor `assetType` | `1` (`AssetType.ERC20`) on every `addAssets` call | `deployAdaptors` helpers | — |
| Post-deploy state | `pause()` before ownership handover | `main()` | — |

The Pool threshold (30 h) is now looser than the Paymaster's (24 h). The split is intentional —
see the comment at [`Paymaster.sol:28-31`](../src/core/Paymaster.sol#L28-L31): TVL feeds (asset/USD) and the
fee-conversion feed (ETH/asset) have different update cadences.

---

## 2. `common` block — all chains

`script/config.json` → `common`

| Key | Value | Consumed by |
|---|---|---|
| `withdrawFeeBps` | **0** | `PoolConfigParams.withdrawFeeBps`. Cap `MAX_WITHDRAW_FEE_BPS = 2500` (25%) |
| `protocolVersion` | **1** | `setVersion()` post-init |
| `commitmentTreeDepth` | 25 | **unused by this script** — mirrors `COMMITMENT_TREE_DEPTH` |
| `addressTreeDepth` | 20 | **unused by this script** — mirrors `MERKLE_TREE_DEPTH` |
| `hardwareWalletOwner` | `0xa285717BfD608468566bfBda742b56b1177494f7` | Final owner of PoolProxy, Verifier, AdaptorHandler, Gateway, Paymaster — **and** the Verifier's `verifierManager` |
| `pauserAddress` | `0x50887b9a36E734cF861FE236fA6b4bE68D205113` | `InitAddressParams.pauser`. Can `pause()`; `unpause()` is `onlyOwner` |
| `veilnyxMultiSigAddress` | `0x9bAf694B165c42850BD3c9c944E16d48d566C617` | **Loaded and never used** — no reference outside `configs.ts` |
| `env` | `"testnet"` | Destructured away in `configs.ts` and **never read** — no mainnet guard |

### Revoker (single entry)

| Field | Value |
|---|---|
| `name` | `Veilnyx Security Group` |
| `description` | `A compliance group for dApps, ensuring private yet compliant revocation processes.` |
| `revokerPublicKey[0]` | `19670944452806042525069794818829249411975318219685565589987272359777840230253` |
| `revokerPublicKey[1]` | `5705876210490413354479267746861793442476799294826521514340924438581325830039` |
| `encryptionPublicKey[0]` | `8415733266590874906051569398859887253801673499116319370506942542327247131378` |
| `encryptionPublicKey[1]` | `4303763666990812745724909494561603880133773663501392405214554054831058921986` |

Both keys are BabyJubJub points, on-curve checked at registration. A pool with no active revoker
reverts every `transact` with `InvalidRevoker`.

---

## 3. Per-chain parameters

### 3.1 Ethereum mainnet (chainId 1)

| Key | Value |
|---|---|
| `entryPoint` | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` (EntryPoint v0.7) |
| `nativeWToken` | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` (WETH) |
| `sanctionsList` → `screener` | `0x40C57923924B5c5c5455c48D93317139ADDaC8fb` (Chainalysis oracle, passed raw — no `Screener` wrapper) |
| `initAssetType` | `1` (ERC20) |
| `initAssetAddresses` | WETH `0xC02aaA39…756Cc2`, USDC `0xA0b86991…06eB48` |
| `initAssetsPrecision` | `[18, 6]` |
| `initAssetToUSDChainlinkFeeds` (Pool TVL) | `[0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 0x84E045745ED829c5b778aBB17104FC2600020850]` (ETH/USD, USDC/USD) |
| `initNativeGasTokenToAssetChainlinkFeeds` (Paymaster) | `[0x0 → GAS_ASSET_ID passthrough, 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419]` |
| `initAssetIdsVeilnyx` | `[65537, 65538]` |
| `poseidonT3` / `poseidonT4` / `nebraVerifier` / `gateway` / `paymaster` | all `0x0` — **ignored**; Poseidon, Gateway and Paymaster are redeployed on every run |

### 3.2 Tenderly mainnet simulation (chainId 7800)

Identical to mainnet except `initAssetToUSDChainlinkFeeds` = `[0x0, 0x0]`, so `getTvlUsd()` reads 0
and the $5,000 cap is inert on this network.

### 3.3 Sepolia (chainId 11155111)

| Key | Value |
|---|---|
| `entryPoint` | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| `nativeWToken` | `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14` |
| `sanctionsList` | **`0x0` → screening disabled** |
| `initAssetAddresses` | WETH `0xfFf99767…24d6B14`, USDC `0x1c7D4B19…9C7238`, stETH `0x3e3FE7dB…9b40Af`, aWETH `0xC558DBdd…629a3c`, aUSDC `0x94a9D9AC…5d5E4C8` |
| `initAssetsPrecision` | `[18, 6, 18, 18, 6]` |
| `initAssetToUSDChainlinkFeeds` | `[0x694AA176…C325306, 0xA2F78ab2…5270E, 0x0, 0x0, 0x0]` |
| `initNativeGasTokenToAssetChainlinkFeeds` | `[0x0, 0x694AA1769357215DE4FAC081bf1f309aDC325306, 0x0, 0x0, 0x0]` |
| `initAssetIdsVeilnyx` | `[65537, 65538, 65539, 65540, 65541]` |

### 3.4 Other configured chains (no `adaptorConfig` entry — not runnable with this script)

| Chain | id | `nativeWToken` | `sanctionsList` | Base assets | USD feeds set |
|---|---|---|---|---|---|
| local | 31337 | `0x0` | `0x0` | 2 | none |
| optimism-sepolia | 11155420 | `0x4200…0006` | `0x8397daDcB6B284F4f5988128cAfc72Ee706d88f2` | 2 | both |
| polygon-amoy | 80002 | `0xaFE07e24…0fAEE1` | `0x2089c78f8247F42e7EbE328874963e856a77B22f` | 2 | both |
| holesky | 17000 | `0x94373a49…EF3848` | `0x0` | 3 | none |
| veilnyx-appchain-testnet | 34244 | `0xC047cfab…6E1893` | `0x0` | 2 | none |
| arc-testnet | 5042002 | `0x911b4000…82Df` | `0x0` | 1 | none |

Note on polygon-amoy: `GAS_ASSET_ID = 65537` resolves to WETH, but the chain's gas token is POL/MATIC.

---

## 4. Adaptor configuration

### 4.1 Mainnet (chainId 1) — enabled adaptors only

| Adaptor | Constructor args | Asset registered | Precision | USD feed |
|---|---|---|---|---|
| UniswapV3 | router `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` | none | — | — |
| AaveV3 | pool `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`, staticTokenFactory `0x411D79b8cC43384FDE66CaBf9b6a17180c842511` | staticAWETH `0x252231882FB38481497f3C767469106297c8d93b` | 18 | `0x5424384B256154046E9667dDFaaa5e550145215e` |
| | | staticAUSDC `0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6` | 6 | `0x84E045745ED829c5b778aBB17104FC2600020850` |
| Lido | lido/stETH `0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84`, wstETH `0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0`, withdrawalQueue `0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1`, wETH `0xC02aaA39…756Cc2` | wstETH | 18 | **`0x0`** |
| Morpho | pool only | Gauntlet WETH Prime `0x2371e134e3455e0593363cBF89d3b6cf53740618` | 18 | **`0x0`** |

### 4.2 Mainnet — configured but currently disabled

| Adaptor | Assets | USD feeds |
|---|---|---|
| Curve | USDT `0xdAC17F95…831ec7`, crvUSD `0xf939E0A0…ac1b4E`, crvUSD/USDT LP `0x390f3595…97BF4`, crvUSD/sUSDe LP `0x57064F49…82e85` | `0x3E7d1eAB…4e32D`, `0xEEf0C605…9cD49F`, `0x0`, `0x0` |
| Ethena | USDe `0x4c9EDD58…1E68B3`, sUSDe `0x9D39A5DE…7A3497` | `0xa569d910…69F961`, `0xFF3BC18c…6aD099` |
| Beefy | mooCurveCrvUSDsUSDe `0xBF7fc2A3…CE96A5` | `0x0` |
| RocketPool | rETH `0xae78736C…Fc6393`, router `0x16D5A408…f1c1C` | `0x0` |
| 1inch | router `0x111111125421cA6dc452d289314280a0f8842A65` | — (no assets) |

### 4.3 Sepolia (chainId 11155111)

| Adaptor | Assets | USD feeds |
|---|---|---|
| UniswapV3 | router `0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E` | — |
| AaveV3 | staticAWETH `0x162B5005…12E98`, staticAUSDC `0x8A881245…3751e` | `0x694AA176…C325306`, `0xA2F78ab2…5270E` |
| Lido | wstETH `0xB82381A3fBD3FaFA77B3a7bE693342618240067b` | `0xaaabb530…BE218E` |
| Morpho | **`0x0`** — vault is mainnet-only | `0x0` |
| Curve / Ethena / Beefy / RocketPool | all **`0x0`** | mixed |

### 4.4 Resulting asset IDs

IDs come from a monotonic per-type counter ([`AssetLogic.sol:72-76`](../src/libraries/AssetLogic.sol#L72-L76)),
format `1 byte assetType | 2 bytes counter`. Base assets are registered before any adaptor, so
`65537` (`GAS_ASSET_ID`) is always the wrapped native token regardless of which adaptors are enabled.

| ID | Mainnet, current adaptor set | Sepolia, as deployed |
|---|---|---|
| 65537 | WETH | WETH |
| 65538 | USDC | USDC |
| 65539 | staticAWETH | stETH |
| 65540 | staticAUSDC | aWETH |
| 65541 | wstETH | aUSDC |
| 65542 | Gauntlet WETH Prime | staticAWETH |
| 65543 | — | staticAUSDC |
| 65544 | — | wstETH |

Enabling a commented-out adaptor shifts the IDs of every adaptor *after* it in `deployAdaptors`
(e.g. enabling Curve moves the Morpho vault from 65542 to 65546). Base asset IDs are unaffected.
There is no renumbering path — `updateAsset` only toggles `isActive` and the counter never decrements.

---

## 5. Contract-enforced bounds (not deploy-configurable)

[`src/base/Constants.sol`](../src/base/Constants.sol)

| Constant | Value |
|---|---|
| `MAX_WITHDRAW_FEE_BPS` | `2500` (25%) |
| `MIN_PRICE_STALENESS_THRESHOLD` | `1 hours` |
| `MERKLE_TREE_DEPTH` | `20` |
| `COMMITMENT_TREE_DEPTH` | `25` |
| `TREE_UPDATE_QUEUE_SIZE` | `10` |
| `TVL_USD_DECIMALS` | `6` |
| `COMMITMENT_MERKLE_TREE_ROOT_HISTORY_SIZE` | `100` |
| `USER_REGISTER_MERKLE_TREE_ROOT_HISTORY_SIZE` | `50` |
| `EIP712_DOMAIN_NAME` / `_VERSION` | `"Veilnyx"` / `"1"` — must never change |
| `Paymaster.GAS_ASSET_ID` | `65537` |

---

## 6. Review findings

### 6.1 The TVL cap is bypassable via `CALL_ADAPTOR`

Direct deposits of unpriced assets **are** blocked — `_getDepositUsd` reverts with
`DepositRestrictedAsAssetFeedNotSet` ([`Pool.sol:710-712`](../src/core/Pool.sol#L710-L712)). But
`CALL_ADAPTOR` is a separate `ShieldedTransactionType` and `_runDepositGuardRails` returns
immediately for it ([`Pool.sol:636`](../src/core/Pool.sol#L636)); its only validation is that the
adaptor is whitelisted. So:

1. Deposit WETH — priced, counts toward the $5,000 cap.
2. `CALL_ADAPTOR` → Lido/Morpho converts pool-held WETH into wstETH or vault shares. No guard rail runs.
3. `getTvlUsd()` skips those balances ([`Pool.sol:734`](../src/core/Pool.sol#L734)) — measured TVL falls toward zero.
4. Deposit another $5,000. Repeatable.

With Lido and Morpho both enabled on mainnet and both carrying `0x0` feeds, the cap bounds only idle
WETH/USDC, not protocol value. Fix: set real feeds for wstETH and the Morpho vault (the `@todo` at
`configs.ts:89` proposes a controlled mock aggregator as the interim), or ship mainnet with
uniswap + aave only.

### 6.2 The unpriced-deposit block is coupled to the limits being enabled

`_runDepositGuardRails` early-returns before reaching the feed check when
`_min == 0 && _max == max && _tvl == max` ([`Pool.sol:643-644`](../src/core/Pool.sol#L643-L644)).
Current config keeps it live, but lifting the caps later via `setDepositLimits` / `setTvlLimit`
silently removes the `DepositRestrictedAsAssetFeedNotSet` protection too.

### 6.3 Every setup call in the deploy script is non-fatal

`addAssets`, `addAdpatorSupport`, and `addAssetsAndRevokers` each catch and log. If the base
`addAssets` reverts, the first adaptor's assets take 65537/65538 — `GAS_ASSET_ID` then resolves to
staticAWETH, revokers are never registered (same try block), and the pool is bricked. The run still
pauses, transfers ownership, and **exits 0**. Not recoverable in place; requires a proxy redeploy.

Suggested: rethrow on failure, or assert `getAsset(65537).assetAddress == chainParams.nativeWToken`
before `deployAdaptors`.

### 6.4 One key holds owner and `verifierManager`

`deployVerifier(deployConfig, commonParams.hardwareWalletOwner)` sets `verifierManager`, and the
same address then receives ownership of all five Ownable contracts. The role split in `Verifier.sol`
collapses to one signer. `veilnyxMultiSigAddress` is loaded but never wired in.

### 6.5 Mainnet limits are testnet-shaped and hardcoded

$5,000 TVL / $2 min / $200 max ship as-is to `deployCoreWithAdp:mainnet`. If deliberate for a soft
launch, fine; otherwise these belong in per-chain config, since `env: "testnet"` is not enforced anywhere.

### 6.6 Three different ETH/USD-family feeds on mainnet

Base WETH uses `0x5147eA64…`, staticAWETH uses `0x5424384B…`, the Paymaster uses `0x5f4eC3Df…`
(the canonical mainnet ETH/USD). Verify each before mainnet:

```sh
cast call <feed> "description()(string)" --rpc-url $RPC_ETHEREUM_MAINNET
cast call <feed> "decimals()(uint8)"     --rpc-url $RPC_ETHEREUM_MAINNET
```

### 6.7 Static aTokens are priced with their underlying's feed

staticAUSDC on chain 1 uses the same feed as plain USDC (`0x84E045…`); chain 7800 uses a different
one (`0xB00341…`) for the same asset. Static aTokens appreciate against the underlying, so this
undercounts TVL and drifts over time.

### 6.8 Dead config

`poseidonT3`, `poseidonT4`, `gateway`, `paymaster`, `nebraVerifier` are read into `ChainParams` but
the script redeploys Poseidon/Gateway/Paymaster unconditionally and never touches `nebraVerifier`.
The stale Sepolia `gateway`/`paymaster` values look authoritative but are not.

---

