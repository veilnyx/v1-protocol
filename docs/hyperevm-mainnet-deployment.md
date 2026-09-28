# Deploying the Veilnyx pool to HyperEVM mainnet (chain 999)

> **Start with the full guide:** `veilnyx-hyperliquid/docs/HYPERLIQUID_MAINNET_DEPLOYMENT.md`. It covers
> the pool (this runbook), proving keys, the revoker, the burner-funding adaptor, the frontend and go-live.

Branch `feat/hyperevm-mainnet-deploy`, based on **`fix/pool-security-2026-09`** (PR #38):
`72cb8de`, the commit the Ethereum pool was built from, plus the 2026-09 security fixes.
**The deployment is independent of Ethereum.** It does not wait for the Ethereum upgrade and does
not compare against Ethereum; it is verified against this commit's own build.

## What you are deploying

- The pool with **all 2026-09 security fixes** (see `docs/pool-security-upgrade-2026-09.md`):
  - fee credits must be paid by a public asset (`UnbackedFee`);
  - nullifiers, commitments and `notesMemo` words must be `< p` (`NonCanonicalFieldElement`);
  - `batchSize = 0` tree updates are rejected;
  - deposits screen `tx.origin` and registrations screen the signer, whenever screening is enabled;
  - owner `withdrawPaymasterFeeFor`.
- The Paymaster is the live Ethereum Paymaster's source (`aca3110`: fee checked against the
  effective gas price), plus the fee-paid check and `claimPoolFees`.
- A dry run on a HyperEVM mainnet fork (2026-09-28) produced 24 contracts. `verify-deployment.py`
  confirmed all 24 byte-identical to this commit's Hardhat build, with only library links and
  immutables masked, at the compiler-reported offsets. It also confirmed their wiring. Live
  probes on the deployed pool hit every new check (step 1).
- The verifiers carry the production ceremony keys (`8a65d25`). They are unchanged by the fixes,
  so the Ethereum zkeys serve 999. **Never deploy or prove with the 998 testnet circuits**: they
  use test entropy and their proofs are forgeable.
- On top of the security fixes, this branch only changes deploy tooling and config:

| File | Change |
|---|---|
| `script/config.json` | `"999"` entry: WHYPE (asset 65537, the paymaster's gas asset) then Circle USDC `0xb88339…630f` (65538, precision 6); RedStone HYPE/USD + USDC/USD feeds; `screeningDisabled: true` |
| `script/adaptorConfig.json` | `"999"` entry with every address zero, so no adaptors are deployed |
| `script/utils/hyperevmPreflight.ts` | New checks run before any gas is spent (below) |
| `script/deployCoreWithAdp.ts` | Runs the preflight on 999; skips the adaptor step when a chain configures none (chain 1 is unchanged) |
| `script/utils/chainUtils.ts` | viem maps chain id 999 to *Wanchain Testnet*; 999 now gets its own HyperEVM definition |
| `hardhat.config.ts`, `package.json` | `hyperevm` + `hyperevmFork` networks and commands |
| `script/hyperevm/verify-deployment.py` | Post-deploy proof that what landed is this commit's build, correctly wired. Needs only the 999 RPC |
| `script/hyperevm/check-zkeys.py` | Checks a zkey set against the ceremony manifest |

The existing guards all still apply:

- refuses a live run if the owner is unset or is the deployer;
- checks the RPC's chain id matches;
- checks the verifier sources against the ceremony manifest;
- checks the deployer's balance;
- **pauses the pool before any setup**;
- transfers every `Ownable` contract to the owner, then fails the run if any are still deployer-owned.

## Decisions to confirm before running

| Decision | Current value | Where |
|---|---|---|
| **Owner** of Pool (UUPS upgrades), Verifier, AdaptorHandler, Gateway, Paymaster | `0xa285717B…94f7`, the hardware wallet that also owns the Ethereum pool. Set a Safe address here if you want a multisig. It must be funded with HYPE on 999 and should prove control with one transaction on 999 **before** the deploy | `common.hardwareWalletOwner` |
| Pauser | `0x50887b9a…5113` (same as Ethereum) | `common.pauserAddress` |
| **Sanctions screening** | **Disabled.** Chainalysis' oracle does not exist on HyperEVM. To screen instead, deploy a list contract and set `sanctionsList`, removing `screeningDisabled` | `"999".sanctionsList` / `screeningDisabled` |
| Revoker | "Veilnyx Security Group", same keys as Ethereum | `common.revokers` |
| Limits | TVL $5,000; deposits $10–$250 (script defaults, same as Ethereum) | `deployCoreWithAdp.ts` `configParams` |
| Oracle staleness | Pool 30h, Paymaster 24h; RedStone heartbeat is 6h | script defaults |

## Steps

### 0. Prepare a deployer (fresh key, not privileged afterwards)

The deployer only broadcasts; the script leaves it owning nothing. Use a **fresh key**, never the
testnet relayer `0xd5182b47…`.

1. **Fund it with HYPE on HyperEVM.** The script warns below 0.15 and sends 0.03 to the paymaster's
   EntryPoint deposit. 0.3 HYPE is comfortable.
2. **Make it a HyperCore user.** Send ≥ 2 USDC to it on HyperCore from any Core account, e.g. an
   `app.hyperliquid.xyz` spot transfer. The first transfer to a new account pays a ~1 USDC fee.
3. **Enable big blocks.** Small blocks cap a transaction at 3M gas, and `ShieldedTransactionLogic`
   alone needs more (the dry run hit this). With the Python SDK, signed by the deployer key:

   ```python
   from eth_account import Account
   from hyperliquid.exchange import Exchange
   from hyperliquid.utils import constants
   Exchange(Account.from_key(DEPLOYER_KEY), constants.MAINNET_API_URL).use_big_blocks(True)
   ```

   Check: `eth_usingBigBlocks(deployer)` must return `true`. The script refuses to start otherwise.

### 1. Dry run on a fork

```bash
pnpm install --frozen-lockfile
# .env: RPC_HYPEREVM_MAINNET=<https RPC>, PRIVATE_KEY=<anything for the fork>
pnpm fork:hyperevm                       # terminal 1 (anvil, 30M-gas blocks = big blocks)
pnpm deployCoreWithAdp:hyperevm:fork     # terminal 2
npx hardhat compile
python3 script/hyperevm/verify-deployment.py deployments/hyperevmFork-999.json --rpc http://127.0.0.1:8547
```

Expect:

- "HyperEVM preflight passed";
- every contract deployed;
- "Pool: paused";
- feeds set;
- "asset 65537 = 0x5555… (nativeWToken)";
- "No adaptors configured";
- five ✅ ownership transfers;
- `verify-deployment.py` printing **`DEPLOYMENT OK: 24 contracts identical to this build, wiring verified`**.

Optionally, confirm the fixes on the fork. Impersonate the owner, `unpause()`, then `cast call`
the pool; each call must revert with the error shown:

| Call | Expected revert |
|---|---|
| `transact` with nullifier `p + 1` | `NonCanonicalFieldElement` |
| `transact` with commitment `p + 7` | `NonCanonicalFieldElement` |
| WITHDRAW whose fee is larger than its public amount | `UnbackedFee` |
| 20 USDC DEPOSIT with a fee | `UnbackedFee` |
| tree update with `batchSize = 0` | `InvalidBatchSize` |

All five passed on the 2026-09-28 dry run.

### 2. Live run

```bash
# .env: PRIVATE_KEY=<fresh deployer>, RPC_HYPEREVM_MAINNET=<RPC>, ETHERSCAN_API_KEY=<for hyperevmscan>
pnpm deployCoreWithAdp:hyperevm
```

The run writes `deployments/hyperevm-999.json` before contract verification, so the addresses
survive even if verification fails. Commit that file.

### 3. Verify, then (owner) unpause

1. Run `python3 script/hyperevm/verify-deployment.py deployments/hyperevm-999.json --rpc $RPC_HYPEREVM_MAINNET`
   from this commit, after `npx hardhat compile`. Anything other than `DEPLOYMENT OK` means
   **do not unpause**. It checks every contract against this build, byte for byte including
   metadata, and it checks the wiring:
   - the proxy implementation;
   - the Pool's verifier, hasher, adaptor handler and native token;
   - all nine verifiers registered in the router;
   - the Gateway, Paymaster and Hasher immutables.
2. Check `owner()` on all five contracts = the owner. The deployer must own nothing. The script
   asserts this, but re-read it from a block explorer.
3. Check `getAsset(65537)` = WHYPE and `getAsset(65538)` = Circle USDC with precision 6; the
   paymaster feeds for 65537 and 65538; the revoker via `getRevokerData(0)`.
4. **Owner** calls `unpause()` on the pool.
5. Run a tiny real round trip through the app (deposit → shielded transfer → withdraw).

### 3b. Proving keys — required before unpausing

999 proves with the **Ethereum ceremony zkeys** (`mainnet-circuits`); the hyperliquid app routes
chain 999 there. Whatever host serves them must pass:

```bash
python3 script/hyperevm/check-zkeys.py https://<circuits-host>/mainnet-circuits   # must print "all 9 match"
```

Found 2026-09-25:

- **`https://app.veilnyx.com/mainnet-circuits` serves the OLD pre-remediation keys for all nine
  circuits.** The register key has 5 public inputs, where the live verifier has 6. Its
  `transact84/keys.zkey` is actually the old ceremony's transact82 key. Every proof made with
  that set fails against the live verifiers.
- The correct keys for 8 circuits are in `v1-interface/public/mainnet-circuits` (verified).
- **The correct `transact84` zkey is not in any copy we found.** Recover it from the `8a65d25`
  ceremony outputs.
- If that host is what Ethereum-mainnet users prove against, Ethereum is affected too.

### 4. Relayer-free burner funding (separate repo)

`HyperCoreFundingAdaptor` lives in `veilnyx-hyperliquid/protocol`. Deploy it with
`DeployHyperCoreFunding.s.sol` (`POOL=<this proxy>`). The owner then runs the printed
`addAdaptorSupport(adaptor, true)`, and someone sends ~0.05 HYPE to this pool's AdaptorHandler.
See `veilnyx-hyperliquid/docs/MAINNET_DIRECT_FUNDING.md`.

## Security review (2026-09-25)

**Update 2026-09-25/28:** a fresh audit of `72cb8de` found two Critical issues (fee-credit mint,
nullifier `n + p` double-spend), a High (tree freeze) and several Mediums. All are fixed on the
base branch of this one; see PR #38 and `docs/pool-security-upgrade-2026-09.md`. The review below
predates that audit and still applies to everything it covers.

The pool was re-audited for this deployment. There were two independent passes:

- **Provenance:** the live Ethereum pool was rebuilt from source and matched byte for byte to 72cb8de.
- **Findings:** every audit finding was checked against that exact code.

**Verdict: acceptable with the conditions below.** Deploying `origin/mainnet` or `831794a` (the
`veilnyx-hyperliquid` submodule pin) instead would **not** be acceptable. Both still carry:

- **C-1**, verifier calldata length: anyone can drain the pool;
- **C-2**, the circuit's pubAssets conservation: any registered user can drain it.

72cb8de contains every fix: C-1, C-2, H-1, H-2, L-1, L-2, I-1, I-2, pubFlow binarity and
register binding. The ceremony was run over the fixed circuits (constraint matrices verified
against a fresh compile).

Conditions, with their status on this branch:

| Condition | Status |
|---|---|
| 2026-09 security fixes included | ✅ based on `fix/pool-security-2026-09`; live probes pass on the fork deploy |
| Every contract byte-identical to this commit's build, correctly wired | ✅ 24/24 on the fork dry run; `verify-deployment.py` re-checks the real deploy |
| Verifiers from the 8a65d25 ceremony, not 3fbcd0a / 831794a / a13860c | ✅ manifest check + bytecode |
| Frontend proves 999 with the mainnet circuit set, served correctly (incl. transact84) | app routes 999 to `mainnet-circuits`; **hosting still open, see step 3b** |
| Only non-fee-on-transfer, non-rebasing assets (WHYPE, Circle USDC) | ✅ |
| Commitment tree queue size 10 | ✅ `common.commitmentTreeQueueSize` |
| Paymaster deposit small and monitored | ✅ 0.03 HYPE |
| Independent check of the ceremony transcript against its phase-1 file | open (optional; the phase-1 file was not available locally) |

Known and accepted, same as Ethereum:

- **Zellic "Gateway validateUserOp always succeeds / fee parsing not bound to selector".** The
  paymaster's EntryPoint deposit can be griefed. Pool funds are not at risk.
- **Proofs do not bind chain id.** Cross-chain replay is blocked because each pool only accepts its
  own tree roots, which diverge at the first deposit.

Chain compatibility:

- The code deployed is the audited Ethereum code plus the 2026-09 fixes. That includes the
  crypto-audit remediation (1e6f04d) and its ceremony.
- HyperEVM is compatible:
  - the BN254 and modexp precompiles return identical results;
  - the code targets EVM `paris` with no transient storage or blob opcodes;
  - EntryPoint v0.7, both CREATE2 factories and a WETH9-style WHYPE are present;
  - RedStone feeds implement AggregatorV3, and the Paymaster reads `decimals()` dynamically.
- Signatures bind chain id and pool address (EIP-712).
- Proofs do not bind chain id: cross-chain replay is prevented only by each pool accepting its own
  tree roots, which diverge at the first deposit.
