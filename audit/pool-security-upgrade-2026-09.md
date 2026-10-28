# Pool Security Upgrade — 2026-09

Runbook for upgrading a live Veilnyx pool to the fixes on `fix/pool-security-2026-09`, using a
**hardware-wallet owner**. The work is split into two parts:

- An unprivileged deployer deploys the new code.
- The owner signs a short, fixed list of transactions whose calldata is generated and checked
  in advance.

- **Base:** `72cb8de`, which is what Ethereum mainnet runs. This branch is `72cb8de` plus the fixes below.
- **Script:** [`script/upgradePoolSecurity.ts`](../script/upgradePoolSecurity.ts)
- **Regression tests:** [`test/security/`](../test/security)
- **Circuits, zkeys and verifiers:** unchanged. No ceremony is needed, and deployed verifiers are kept.
- **Storage layout:** unchanged. See [§7](#7-how-this-was-tested).
- **Tested against real traffic:** eight historical mainnet transactions were replayed on upgraded forks, and all
  80 historical shielded transactions were checked against the new rules. See [§7](#7-how-this-was-tested).

---

## 1. What is fixed

| # | Severity | Finding | Fix | Where |
|---|---|---|---|---|
| 1 | **Critical** | **Fee mint.** The circuit has no fee signal, but the pool credited `feeData` to any "paymaster". A DEPOSIT, or a zero-value WITHDRAW with the fee in another asset, credited an arbitrary fee to the attacker, who then drained honest deposits through `withdrawPaymasterFee`. Proven with production zkeys. | `validate` requires that a fee is paid by a public asset: not a DEPOSIT, and some `pubAsset` has `id == feeAssetId` and `value >= fee`. Otherwise it reverts with `UnbackedFee`. | `ShieldedTransactionLogic._requireBackedFee` |
| 2 | **Critical** | **Nullifier aliasing double-spend.** Nullifiers reach the proof only through `alpha = sha256(raw words)` and are reduced mod p. So `n` and `n + p` verify alike, but they are different keys in `_markedNullifiers`. The same note could be spent twice. Proven. | Every nullifier, commitment and `notesMemo` word must be `< FIELD_SIZE`. Otherwise the tx reverts with `NonCanonicalFieldElement`. | `ShieldedTransactionLogic._requireCanonicalFieldElements` |
| 3 | High | **Tree freeze.** A commitment `c + p` was queued raw. It can never be a tree-update public input, so the queue stalled forever. Proven. | Same check as #2. As defence in depth, `queueLeaves` also reverts with `InvalidLeaf`. | as #2, plus `QueuedMerkleTreeLogic.queueLeaves` |
| 4 | Medium | **Root-history eviction.** A `batchSize = 0` update is a provable no-op, and its proof replays verbatim. Replaying it 100 times evicts every historic root and invalidates in-flight transactions. | `batchSize == 0` reverts with `InvalidBatchSize`. | `QueuedMerkleTreeLogic._verifyUpdateProof` |
| 5 | Medium | **`notesMemo` ≥ p.** The circuit binds memo words only mod p, so the revoker decrypts garbage. | Same check as #2. | as #2 |
| 6 | Medium | **Paymaster sponsors fee-less ops.** A TRANSFER with no `pubAssets` advertised a fee. The pool ignores `feeData` in that case, so the paymaster paid gas for nothing. | The Paymaster applies the pool's rule and rejects the op in validation with `FeeNotPaidByTransaction`. **The Paymaster is not upgradeable, so it is replaced.** | `Paymaster._requireFeePaidByTransaction` |
| 7 | Medium | **Paymaster fees stuck.** Neither deployed Paymaster can call `pool.withdrawPaymasterFee`. On Ethereum, 0.025323 WETH and 7.385624 USDC are stuck across the two Paymasters (see [§2](#2-what-gets-deployed)). | New owner-only `Pool.withdrawPaymasterFeeFor(paymaster, assetId, to)`. It moves only what is credited to that paymaster. The new Paymaster also gets `claimPoolFees(assetId, to)`. | `Pool`, `Paymaster` |
| 8 | Medium | **Sanctions bypass.** Only `msg.sender` was screened. A sanctioned EOA could deposit through the permissionless `Gateway.handleWrapAndDeposit`, or have anyone relay its `registerAddress`. | Deposits also screen `tx.origin` when it differs from `msg.sender`. Registration also screens the EIP-712 signer. | `Pool._runDepositGuardRails`, `Pool.registerAddress` |

**Exploitation check (Ethereum mainnet, from deployment to 2026-09-25):**

- All 170 nullifiers and 158 commitments are `< p`.
- No two nullifiers alias.
- There have been zero `withdrawPaymasterFee` calls.
- All 51 outflows came from `transact` or `handleOps`.

We found **no sign that any of these issues was exploited**. The issues are live, though, so pause first (step 0).

**Not in this upgrade** (Low; tracked separately):

- instant `verifierManager` swap;
- single-step `Ownable`;
- `Gateway` leftover value;
- adaptor gas-drop faucet;
- 24 h paymaster price staleness;
- the signed hash not covering outputs;
- withdrawals to HyperCore system addresses.

### Behaviour changes for integrators (SDK, relayer, bundler, UI)

- A **DEPOSIT with a non-zero fee** now reverts. Deposits are self-paid and must carry `feeValue = 0`.
- A fee must be ≤ the public amount of its own asset in `pubAssets`. The SDK already complies (`v1-sdk` `transaction/src/helpers.ts` `getPublicAssets`): WITHDRAW and CALL_ADAPTOR set pubValue = value + fee, and TRANSFER sets pubValue = fee. The SDK also refuses a DEPOSIT with a fee (`transaction/src/tx.ts`). No client change is needed apart from the Paymaster address.
- Any nullifier, commitment or `notesMemo` word ≥ p reverts. Honest provers never produce one.
- A tree update with `batchSize = 0` reverts. The tree-update service must not submit an update when the queue is empty.
- A sanctioned EOA calling through any contract is now blocked on deposit. A relayer can no longer register a sanctioned signer.
- **The Paymaster address changes.** `feeData` embeds the paymaster address, and the address is bound into the proof. Every client that builds `feeData` must switch to the new address (step 6). The fee rule itself does not change: the replacement keeps the current Paymaster's effective-gas-price quote ([`paymaster-fee-quoting.md`](paymaster-fee-quoting.md)).
- Pool transactions cost about 10–15k more gas, and paymaster validation about 17k more. Gas is estimated live, so clients need no change. A registration estimated just before the upgrade and mined just after can run out of gas once (+2.85k gas) and must be resent.

---

## 2. What gets deployed

| Contract | Action | Why |
|---|---|---|
| `QueuedMerkleTreeLogic` | **new** | fixes #3 and #4 |
| `ShieldedTransactionLogic` | **new**; links the existing `AssetLogic` and `MerkleTreeLogic` plus the new `QueuedMerkleTreeLogic` | fixes #1, #2 and #5 |
| `Pool` implementation | **new**; links the existing `AssetLogic`, `MerkleTreeLogic` and `ShieldedAddressLogic` plus the two new libraries | fixes #7 and #8; links the new libraries |
| `Paymaster` | **new**; the current Paymaster's source (`aca3110`: fee checked against the effective gas price) plus fixes #6 and #7. Same `entryPoint`, `sender` (Gateway), pool, staleness and feeds as the current one. Owned by the pool owner unless `NEW_PAYMASTER_OWNER` is set. | not upgradeable, so it is replaced |
| `AssetLogic`, `MerkleTreeLogic`, `ShieldedAddressLogic` | reused | Their executable code is identical to this build. Only the metadata hash differs, because `IPool.sol` gained two error declarations. `plan` checks this. |
| `PoolProxy`, `Verifier` + verifiers, `Hasher`, `Gateway`, `AdaptorHandler`, adaptors, `Screener` | unchanged | — |

**Two Paymasters exist on Ethereum.** The pool has credited fees to both, both lack a way to claim them, and the replacement retires both:

| Paymaster | Source | Used | Owner | Stuck fees | EntryPoint deposit |
|---|---|---|---|---|---|
| `0x81b7044bb60f895193e947814b1d9df421e03d66` (**current**) | `aca3110` (byte-identical) | 16 ops, blocks 25 823 126 → 26 054 049 | `0x2985D7e551081b132671FCf3C9D1A75f4FA4cCF8` | 0.005159 WETH, 0.676550 USDC | 0.023477 ETH |
| `0xb75619e85e4d5a16ca4fd050fffff3ff6339f855` (earlier) | `72cb8de` era | 41 ops, blocks 25 648 388 → 25 801 470 | `0xa285717BfD608468566bfBda742b56b1177494f7` | 0.020164 WETH, 6.709074 USDC | 0.016979 ETH |

These are values on 2026-09-25; the script reads them live.

The script finds the reused libraries on-chain. It walks the live implementation's `PUSH20`
operands and matches each target's code against this build, so no addresses are hard-coded.

---

## 3. Prerequisites

- A checkout of this branch.
  ```bash
  pnpm install
  ```
  Also install [Foundry](https://getfoundry.sh), which provides `anvil` and `cast`.
- `.env` with:
  - `RPC_ETHEREUM_MAINNET`: an archive-capable RPC is best; it is used for the fork too.
  - `PRIVATE_KEY`: the **deployer**. This is any EOA, not the owner. It needs about 12 M gas, roughly 0.012 ETH at 1 gwei.
  - `ETHERSCAN_API_KEY`: for source verification.
- The **owner** hardware wallet, `0xa285717BfD608468566bfBda742b56b1177494f7`.
  - It needs about 0.42 M gas across 8 transactions, including funding the new Paymaster.
  - It held 0.075 ETH on 2026-09-25.
- The key for `0x2985D7e551081b132671FCf3C9D1A75f4FA4cCF8`, the current Paymaster's owner. It sends one transaction (step 5, row 7), about 36k gas, and held 0.0035 ETH.
- The **pauser**, `0x50887b9a36E734cF861FE236fA6b4bE68D205113`, **holds 0 ETH**. Either fund it, or
  let the owner send `pause()`, which the owner is also allowed to do.
- Build:
  ```bash
  npx hardhat compile
  ```
  The mainnet contracts were built with Hardhat, so use Hardhat, not forge.

Common environment for the commands below:

```bash
export POOL_PROXY=0x4cecb7f987d220fe2e8608149fa76ed6d021ad11
# current Paymaster FIRST: it is the configuration template for the replacement
export OLD_PAYMASTERS=0x81b7044bb60f895193e947814b1d9df421e03d66,0xb75619e85e4d5a16ca4fd050fffff3ff6339f855
export FEE_RECIPIENT=<treasury address that receives the recovered paymaster fees; default = owner>
# optional: export NEW_PAYMASTER_OWNER=<address>   (default = pool owner)
```

---

## 4. Procedure

### Step 0 — Pause now (recommended; independent of the rest)

Issues #1 and #2 are live on mainnet. Pausing blocks every entry point, including withdrawals. At the
time of writing that freezes about $241 of TVL for the length of the upgrade.

```bash
cast send $POOL_PROXY "pause()" --ledger --rpc-url $RPC_ETHEREUM_MAINNET   # from the pauser or the owner
cast call $POOL_PROXY "paused()(bool)" --rpc-url $RPC_ETHEREUM_MAINNET     # -> true
```

If you use a Trezor, swap `--ledger` for `--trezor`. Add `--mnemonic-derivation-path` or `--hd-paths` if
the account is not at index 0.

### Step 1 — Rehearse on a mainnet fork

```bash
npm run fork:mainnet     # terminal 1: anvil fork on :8546 with chain id 1
# terminal 2:
UPGRADE_STEP=rehearse npx hardhat run script/upgradePoolSecurity.ts --network mainnetFork
```

The rehearsal does the following:

1. It runs the probes against the **old** code. All six must FAIL, which shows that the probes can tell the old code from the new.
2. It deploys everything.
3. It impersonates the pauser, the owner and the current Paymaster's owner, and sends every privileged transaction.
4. It moves both old Paymasters' EntryPoint deposits to the new Paymaster.
5. It runs `verify`.

It must end with `VERIFY OK`. Its output goes to
`deployments/pool-security-upgrade-1-fork-rehearsal.json`. **Never use that file for mainnet.**

### Step 2 — Plan (read-only, mainnet)

```bash
UPGRADE_STEP=plan npx hardhat run script/upgradePoolSecurity.ts --network mainnet
```

Check the output:

- Current implementation: `0x56b5ca5378e3a7920152cadb61f57953abBcFD90`.
- Reused libraries:
  - `AssetLogic` `0x2B556A03…`
  - `MerkleTreeLogic` `0xc5e8eD64…`
  - `ShieldedAddressLogic` `0xdC2B542A…`
- Replaced: old `QueuedMerkleTreeLogic` `0x08c459Dd…` and old `ShieldedTransactionLogic` `0x74d93347…`.
- Owner and pauser are as expected.
- Stuck paymaster fees are shown per asset and Paymaster, with each old Paymaster's owner and deposit.

If the plan cannot identify a reused library, **stop**. The live code is then not what this branch was built from.

### Step 3 — Deploy (deployer EOA)

```bash
UPGRADE_STEP=deploy npx hardhat run script/upgradePoolSecurity.ts --network mainnet
```

This deploys:

- `QueuedMerkleTreeLogic`
- `ShieldedTransactionLogic`
- the `Pool` implementation
- the new `Paymaster`

It copies the current Paymaster's feeds onto the new one and transfers the new Paymaster to the owner (or `NEW_PAYMASTER_OWNER`). It refuses to continue if the old Paymasters differ in `entryPoint`, `sender` or pool. It then writes
`deployments/pool-security-upgrade-1.json`, which holds:

- the addresses;
- a pre-upgrade state snapshot;
- the exact owner transactions, with `to`, `data` and a `cast send` line for each.

**Commit that file.**

None of the new contracts holds any privilege until the owner points the proxy at the new implementation. A
compromised deployer key can therefore only waste gas, and step 4 catches any substitution.

Verify the sources on Etherscan. Use the addresses from `newLibraries` in the JSON. `--libraries` takes a JS file:

```bash
cat > /tmp/stl-libs.js <<EOF
module.exports = { AssetLogic: "<a>", MerkleTreeLogic: "<m>", QueuedMerkleTreeLogic: "<q>" };
EOF
cat > /tmp/pool-libs.js <<EOF
module.exports = { AssetLogic: "<a>", MerkleTreeLogic: "<m>", QueuedMerkleTreeLogic: "<q>",
                   ShieldedAddressLogic: "<s>", ShieldedTransactionLogic: "<t>" };
EOF
npx hardhat verify --network mainnet <QueuedMerkleTreeLogic>
npx hardhat verify --network mainnet --libraries /tmp/stl-libs.js <ShieldedTransactionLogic>
npx hardhat verify --network mainnet --libraries /tmp/pool-libs.js <PoolImpl>
npx hardhat verify --network mainnet <NewPaymaster> <entryPoint> <gateway> $POOL_PROXY 86400
```

### Step 4 — Pre-upgrade check (anyone; do this before signing)

```bash
UPGRADE_STEP=verify npx hardhat run script/upgradePoolSecurity.ts --network mainnet
```

At this point the proxy still points at the old implementation. `verify` checks that each newly
deployed contract's on-chain code is **byte-identical** to this build, including metadata:

- It masks only a library's self-address and address immutables: the Pool's UUPS `__self`, and the Paymaster's `entryPoint`, `sender` and `pool`.
- It also checks the new Paymaster's owner, and that its `entryPoint`, `sender`, pool and staleness match the current Paymaster's.

It must print `PRE-UPGRADE CHECK OK`. Anyone who wants to check the deployment independently can run this from a clean checkout of the same commit.

### Step 5 — Privileged transactions, in order

Take the calldata from `ownerTransactions` in the committed JSON. Each entry has its `from`, and the deploy
step also prints a ready `cast send … --ledger` line for each. On the device, confirm the `to` address and
the first 4 bytes of the data.

| # | From | To | Function (selector) | Notes |
|---|---|---|---|---|
| 1 | pauser or owner | pool proxy | `pause()` `0x8456cb59` | Skip if step 0 was done. |
| 2 | owner | pool proxy | `upgradeToAndCall(newImpl, setVersion(2))` `0x4f1ef286` | Upgrades and sets version 2 atomically. The inner call runs as the owner. |
| 3 | owner | pool proxy | `withdrawPaymasterFeeFor(0x81b7…, 65537, FEE_RECIPIENT)` `0xb1bbb965` | 0.005159286108933517 WETH |
| 4 | owner | pool proxy | `withdrawPaymasterFeeFor(0x81b7…, 65538, FEE_RECIPIENT)` `0xb1bbb965` | 0.676550 USDC |
| 5 | owner | pool proxy | `withdrawPaymasterFeeFor(0xb756…, 65537, FEE_RECIPIENT)` `0xb1bbb965` | 0.020163642688626624 WETH |
| 6 | owner | pool proxy | `withdrawPaymasterFeeFor(0xb756…, 65538, FEE_RECIPIENT)` `0xb1bbb965` | 6.709074 USDC |
| 7 | **`0x2985D7e5…`** | **Paymaster `0x81b7…`** | `withdrawFromEntryPoint(0x2985D7e5…, deposit)` `0xc7d76308` | Retires the current Paymaster: with no deposit it cannot sponsor ops. |
| 7b | `0x2985D7e5…` (or anyone) | **new Paymaster** | `depositToEntryPoint()` `0x1b3ba101`, value = the amount from 7 | Funds the new Paymaster. |
| 8 | owner | **Paymaster `0xb756…`** | `withdrawFromEntryPoint(owner, deposit)` `0xc7d76308` | Retires the earlier Paymaster. |
| 8b | owner (or anyone) | **new Paymaster** | `depositToEntryPoint()` `0x1b3ba101`, value = the amount from 8 | |
| 9 | owner | pool proxy | `unpause()` `0x3f4ba83a` | **Only after step 6 below passes.** |

Rows 3–8 carry the values at the time of writing. Use the ones in the JSON: `deploy` reads them live.

Row 7 retires the Paymaster the app uses today, so send it together with the client switch in step 6.2.
Until then the pool is paused and nothing is sponsored anyway.

### Step 6 — Verify, switch the Paymaster, unpause

1. Run the full verification.
   ```bash
   UPGRADE_STEP=verify npx hardhat run script/upgradePoolSecurity.ts --network mainnet
   ```
   The pool is still paused here. The probes use an `eth_call` state override that unpauses the pool for the call only, and nothing is sent. The run must print `VERIFY OK`. It checks:
   - bytecode;
   - the implementation slot;
   - `version == 2`;
   - owner, pauser, verifier, address tree, revoker and every asset: unchanged;
   - balances: changed only by the recovered fees;
   - both old Paymasters: no EntryPoint deposit left;
   - and it probes the new checks live.

   | Probe | Expected revert |
   |---|---|
   | nullifier `p + 1` | `NonCanonicalFieldElement(p+1)` |
   | commitment `p + 7` | `NonCanonicalFieldElement(p+7)` |
   | WITHDRAW whose fee is larger than its public amount | `UnbackedFee(65537,2)` |
   | 20 USDC DEPOSIT with a fee | `UnbackedFee(65538,1)` |
   | tree update with `batchSize = 0` | `InvalidBatchSize()` |
   | `withdrawPaymasterFeeFor` from a non-owner | `OwnableUnauthorizedAccount` |

2. Point every client that builds `feeData` at the **new Paymaster address**:
   - the web app / SDK config;
   - the relayer;
   - the bundler / paymaster service config.

   Ops that still name an old Paymaster fail. It has no deposit, so the bundler rejects them before they reach the chain.
3. Send row 9, `unpause()`.
4. Smoke test with a small withdrawal that pays its fee through the new Paymaster. Then confirm:
   ```bash
   cast call $POOL_PROXY "getCollectedPaymasterFee(uint24,address)(uint256)" 65537 <newPaymaster>
   ```
   The result should be greater than zero. The new Paymaster's owner can later claim it with `claimPoolFees(assetId, to)`.

### Rollback

The proxy's storage layout is unchanged, and the previous implementation is still deployed and linked
to its original libraries. To roll back, the owner calls:

```
upgradeToAndCall(0x56b5ca5378e3a7920152cadb61f57953abBcFD90, setVersion(1))
```

**This brings back every issue above**, so only do it together with `pause()`.

---

## 5. Other deployments

- **Testnets (Sepolia etc.)** carry no real funds, and upgrading them is optional. The same script works with
  `--network sepolia` and that chain's `POOL_PROXY` and `OLD_PAYMASTERS`. For the DEPOSIT fee probe, set
  `PROBE_DEPOSIT_ASSET_ID` and `PROBE_DEPOSIT_AMOUNT` to an asset and amount inside that pool's deposit
  USD bounds. The default is 20 USDC as asset 65538, which is correct for Ethereum.
- **HyperEVM (999)** is not deployed yet. Deploy it fresh from this branch, not from `72cb8de`.
  `feat/hyperevm-mainnet-deploy` must be rebased onto this branch first.

---

## 6. Operational notes

- `pause()` can be sent by the pauser or the owner. `unpause()` is owner-only.
- Paused pools also block `updateCommitmentTree`. Deposits made just before the pause stay queued until unpause. That is harmless.
- The upgrade does not touch `tvlLimitUsd`, the deposit limits, staleness thresholds, adaptors, revokers or verifiers.

---

## 7. How this was tested

1. **Unit and regression tests** (`forge test`). [`test/security/`](../test/security) turns every exploit proof-of-concept into a regression test that asserts the exploit now reverts. Each file also keeps honest control paths.

   | File | Covers |
   |---|---|
   | `FieldCanonicality.t.sol` | Real Groth16 proofs, dev keys. The aliased-nullifier double-spend and the aliased-commitment tree freeze are rejected. Memo word ≥ p. `queueLeaves` defence in depth. `batchSize = 0` replay. Honest deposit, tree update and withdrawal still work. |
   | `FeeBacking.t.sol` | Real proofs, production zkeys. Deposit-fee self-credit, and fee-in-other-asset drain, are rejected. Fee > public amount. Honest fee withdrawal works. Owner-only `withdrawPaymasterFeeFor`. New `Paymaster.claimPoolFees`. |
   | `PaymasterFeeBacking.t.sol` | Real proof. The EntryPoint rejects a fee-less TRANSFER with `AA33 … FeeNotPaidByTransaction`, and the Paymaster's deposit is untouched. |
   | `DepositScreening.t.sol` | The sanctioned `tx.origin` is blocked through the Gateway; a clean origin still works. A relayed registration of a sanctioned signer is blocked. |

   `test/Paymaster.t.sol` also carries the `aca3110` effective-gas-price tests; they pass together with the new fee-paid check.

2. **Full suite.** 189 pass. The same 18 tests fail as on the untouched `72cb8de` baseline, with an identical list: they use stale real-proof fixtures (`InvalidProof` / `UnknownCommitmentTreeRoot`). No new failures.
3. **Storage layout.** `forge inspect Pool storageLayout` is identical to `72cb8de`: 26 entries, same slots, offsets and types. No storage variables were added. The Paymaster's layout is unchanged too, although it is a fresh deployment.
4. **Size.** The Hardhat-built Pool runtime is 22,531 bytes, under the 24,576-byte limit.
5. **Mainnet-fork rehearsal** at block 26 056 792, with the real proxy, owner, pauser, both Paymasters and balances.
   - Gas: deployer 11.92 M; owner 0.42 M; `0x2985D7e5…` 91k; pauser 52k.
   - All six probes fail against the old code and pass against the new.
   - All state checks pass. WETH and USDC balances dropped by exactly the recovered fees: 0.025323 WETH and 7.385624 USDC.
   - The new Paymaster received both old deposits, 0.040457 ETH, and both old Paymasters are left with none.
6. **Historical compatibility (static).** All 80 shielded transactions the pool has processed on Ethereum were decoded: 13 DEPOSIT, 48 CALL_ADAPTOR, 16 TRANSFER and 3 WITHDRAW, 57 of them paying a paymaster fee.
   - Every fee is backed by a public asset of its own id, so `UnbackedFee` would have rejected none of them.
   - All 1,000 `notesMemo` words are below p (maximum 0.9995·p), so the canonicality check would have rejected none of them.
   - `keysMemo` and `assetsMemo` do contain words ≥ p. That is correct: they are not field elements, and the pool does not check them.
7. **Historical replay (dynamic).** For each transaction below:
   - An anvil fork was taken at the block before it, with time pinned to the original block.
   - The full upgrade was rehearsed on that fork, ending in `VERIFY OK`.
   - The original transaction was resent from its original sender with its original calldata and gas limit.

   For the `handleOps` rows, the **new Paymaster's code** was placed at the address the op names. `feeData` binds that address into the proof, and the two contracts have the same immutables and storage layout. This exercises the new validation with the op's real gas limits: the tightest op used 27,058 of its 74,674 paymaster-validation gas.

   | Transaction | Block | Result on upgraded code | Gas: original → upgraded |
   |---|---|---|---|
   | `updateCommitmentTree` (tree service) | 26 054 157 | success, same logs | 842,911 → 843,098 |
   | CALL_ADAPTOR, direct `transact` | 26 054 151 | success, same 23 logs | 956,739 → 966,748 |
   | CALL_ADAPTOR via `handleOps`, WETH fee, new Paymaster | 26 054 049 | success, same 20 logs | 912,761 → 941,244 |
   | TRANSFER via `handleOps`, WETH fee, new Paymaster | 26 054 024 | success, same 7 logs | 663,553 → 695,193 |
   | `registerAddress` | 26 054 015 | success with a fresh gas estimate. The original limit was the exact old estimate, and the new code needs +2.85k. | 1,134,020 → 1,139,703 |
   | WITHDRAW via `handleOps`, USDC fee, new Paymaster | 26 024 715 | success, same 7 logs | 698,075 → 709,381 |
   | WITHDRAW via `handleOps`, WETH fee, 2 assets, new Paymaster | 26 024 687 | success, same 10 logs | 772,175 → 804,409 |
   | DEPOSIT, direct `transact` | 26 024 529 | success, same 5 logs | 714,604 → 724,557 |

   This replay also caught a real problem before release. A first replacement Paymaster built from `72cb8de` rejected the two-asset WITHDRAW with `InsufficientFee`, because the SDK quotes against the effective gas price. The live Paymaster was then confirmed to be `aca3110`, and the replacement was rebuilt on that source.
