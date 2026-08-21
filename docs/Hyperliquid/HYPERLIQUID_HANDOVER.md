# Veilnyx on HyperEVM: handover

Branch: `hyperliquid/testnet-e2e`
Status: **working end to end on HyperEVM testnet (chain 998)**

This document covers what was done, what is verified, what is deliberately not done, and what a
person picking this up needs to know. It assumes no prior context on the HyperEVM work.

---

## 1. What this is

`script/HyperEvmE2E.s.sol` deploys the full Veilnyx stack to HyperEVM and then performs a real
private deposit and withdrawal, with every proof verified on chain. It exists to prove the protocol
runs on HyperEVM before any mainnet commitment is made.

It is a **production stack**, not a test harness. The pool implementation is the real `Pool`.
Registration, deposit and withdrawal verify against real Groth16 verifier contracts. The commitment
tree flush submits a real `treeUpdate` proof to a real `VerifierTreeUpdate`.

That distinction matters because the script previously used `MockPool` and passed
`proof: bytes("")` to a mock verifier for the tree update, which meant a successful run proved
almost nothing about the real protocol.

---

## 2. Verified on chain

Deployed to chain 998 and confirmed by reading chain state, not by trusting script output:

```
pool proxy    0x434241992d374652bFf69C32c118C365F628364e
verifier      0x24d141053D1ae61eF17055C468e4dCaD0717Bd15
asset1 token  0x6aca105834735fdc8b31d41b087dd0310f0e6646

broadcast receipts     29/29 successful
pool token balance     9990.005000
commitment tree        nextLeafIndex=2  queueStart=2  queueEnd=3
```

The balance is the proof of the full cycle: 10,000 deposited, 9.995 withdrawn after the 0.005 fee.
The tree shows two commitments inserted and flushed, with the withdrawal's output note queued
behind them.

---

## 3. The blocker, and how it was solved

HyperEVM has a dual block architecture. Small blocks are produced every second with a **3,000,000
gas limit**; big blocks are produced every minute with a **30,000,000** limit. The Veilnyx verifier
contracts do not fit in a small block, so every deployment transaction was rejected at
`eth_sendRawTransaction` with `exceeds block gas limit` before it ever executed.

Big blocks are enabled per address, as a flag on the **HyperCore** user, not on HyperEVM:

```python
from eth_account import Account
from hyperliquid.exchange import Exchange
from hyperliquid.utils import constants

wallet = Account.from_key(PRIVATE_KEY)
ex = Exchange(wallet, constants.TESTNET_API_URL)
ex.use_big_blocks(True)      # -> {'status': 'ok', 'response': {'type': 'default'}}
```

Requires `pip install hyperliquid-python-sdk`.

**The deploying address must already be a HyperCore user** to send this action. An EOA becomes one
by receiving a Core asset such as USDC on HyperCore. Note that HyperEVM and HyperCore are separate
ledgers: sending an ERC20 on HyperEVM does **not** make an address a Core user, and neither does
holding native HYPE for gas. Check with:

```
curl -s -X POST https://api.hyperliquid-testnet.xyz/info \
  -H 'content-type: application/json' \
  -d '{"type":"spotClearinghouseState","user":"<ADDRESS>"}'
```

An empty `balances` array means the address is not a Core user and the action will fail. The
testnet faucet at `app.hyperliquid-testnet.xyz/drip` can fund a Core account, but it requires the
address to already exist on HyperLiquid **mainnet**, so it is not always available for a fresh
deployer. A spot send from an existing Core account is the alternative.

---

## 4. How to run it

```
# once per deploying address
python3 enable_big_blocks.py           # the snippet in section 3

# then
PRIVATE_KEY=0x...  forge script script/HyperEvmE2E.s.sol:HyperEvmE2E \
  --rpc-url https://rpcs.chain.link/hyperevm/testnet \
  --broadcast --slow --non-interactive
```

Four things that will otherwise cost time:

- **`PRIVATE_KEY` needs the `0x` prefix.** `vm.envUint` rejects it otherwise.
- **Use `rpcs.chain.link/hyperevm/testnet`.** The Alchemy HyperEVM endpoint fails under Foundry
  with `-32602 Unknown block number` when it queries account state, even though `cast` reads the
  same state fine. The public `rpc.hyperliquid-testnet.xyz/evm` endpoint has also returned 502s.
- **`--slow` is required, not optional.** HyperEVM's mempool accepts only the next 8 nonces per
  address, so firing the whole sequence at once gets most of it dropped.
- **Expect 30 to 45 minutes.** Big blocks are produced once a minute and `--slow` waits for each
  receipt. This is not a hang.

---

## 5. Circuits and fixtures on this branch

The ceremony zkeys were not available locally, so proofs could not be generated against the
deployed mainnet verifiers. Per the approach used during Ethereum testing, four circuits were
recompiled with a fresh single phase 2 contribution: `register`, `transact21`, `transact22` and
`treeUpdate`. Each produces a self consistent zkey, wasm and ejected Solidity verifier, and those
verifiers replace their counterparts in `src/verifiers`.

Fixtures were regenerated against those keys in dependency order: `register_sender`,
`deposit_pre_tx`, `withdraw_10_weth_with_weth_fee`, then the tree update set.

`test/fixtures/scripts/genHyperEvmTreeUpdate.ts` was added. It proves the tree update over the
commitments `deposit_pre_tx` actually queues. The pre existing `tree_update_data_*` fixtures prove
insertion of `fixture.leavesQueue1`, an arbitrary config set, so submitting one after a deposit
advances the tree to a root the pool has never held and the following withdrawal reverts with
`UnknownCommitmentTreeRoot`. A deposit queues fewer leaves than `queueSize`, so it uses the
`forceUpdate` partial queue path.

Two things worth knowing before regenerating anything:

- **Circuits must be fully regenerated before fixtures.** Recompiling a circuit after generating
  fixtures silently invalidates every proof made with the old key.
- **Regeneration can change which verifier a fixture needs.** The regenerated `deposit_pre_tx` is
  2 in / 2 out and routes to verifier id 22, where the previous one was 2 in / 1 out and routed to
  21. That is why a fourth circuit had to be compiled mid way.

---

## 6. Limitations, read before relying on this

- **This branch is testnet only and is not mergeable to `stage`.** It carries locally generated
  single contribution keys, which are not the ceremony keys, and regenerated fixtures that
  invalidate every other fixture spending the old deposit notes. Its Ethereum tests are expected to
  fail. That is by design and is why the work is isolated here.
- **`version()` reads 0.** This script never sets the protocol version, unlike
  `deployCoreWithAdp.ts`. Harmless for a smoke test, but it should be set for anything real.
- **Screener, price feeds and tokens are mocks.** The proof path is real; the surrounding
  environment is not. `MockScreener`, `MockAggregatorV3` and `MockERC20` are still used, and native
  ETH deposits are out of scope because `Config` is deliberately not deployed.
- **Only four circuits exist on this branch.** `transact23`, `transact42`, `transact44`,
  `transact82` and `transact84` were not regenerated, so transactions of those shapes will fail.
  The end to end path does not use them.
- **No adaptor was exercised.** Deposits and withdrawals only. Morpho and the other adaptors are
  untested on HyperEVM.

---

## 7. Suggested next steps

1. **Repeat the deployment from the intended production deployer.** Whichever address is chosen
   needs `use_big_blocks(True)` run against it, which needs it to be a HyperCore user first.
2. **Decide on keys.** A real HyperEVM deployment needs either its own ceremony or an explicit
   decision that a single contribution setup is acceptable for that network.
3. **Set the protocol version** and replace the mock screener and price feeds with real ones.
4. **Exercise an adaptor.** The Morpho path is the obvious candidate given it is already working on
   Ethereum mainnet.
5. **Decide the repository shape.** Contracts, circuits and the SDK are shared across chains; only
   deployment scripts, chain config and key sets differ. A full per chain fork would duplicate the
   shared majority and require back porting audit fixes to both, which is how stale verifier
   problems tend to start. A shared core with per chain deployment repos is worth considering
   before the split hardens.

---

## 8. Related fix landed elsewhere

`Veilnyx-Hyperliquid` carries a chain agnostic repair that is worth merging independently:
`getConfigWithDefaults` in `@veilnyx-sdk/core` rejects a partial service set, and
`test/fixtures/scripts/sdk.ts` never passed `addressResolver`, so **every** fixture generation run
failed before producing anything. This is likely part of why fixture regeneration has been partial.

Two environment issues found alongside it, neither fixed:

- `@veilnyx-sdk/core` ships a `dist/cjs` without the `{"type":"commonjs"}` marker its own
  `build:cjs` script writes, so a linked core fails with `exports is not defined` until rebuilt.
  Every other SDK package has the marker.
- `RPC_ETHEREUM_SEPOLIA` in `.env` is origin whitelisted and returns 403 from a CLI, which blocks
  fixture generation.

---

## 9. HyperCore integration: feasibility notes

Forward looking. Nothing in this section is built. It records what was verified on chain and what
the open questions are, so the next person does not have to rediscover it.

The goal being explored is private perp positions: the position itself is public and openly the
pool's, while the link between a user and their position stays private, carried by an encrypted
note. Isolated margin is wanted so one user's liquidation cannot affect another's.

### Verified present on chain 998

- **CoreWriter** at `0x3333333333333333333333333333333333333333`, 544 bytes of code.
- **Read precompiles** in the `0x800` range respond. `0x806` and `0x807` (oracle prices) return
  values for a single word input. `0x800`, `0x801` and `0x802` reject that input, which is expected:
  position and balance reads take structured arguments such as `(user, perp)`, not a bare index.

That contracts can read HyperCore positions on chain matters for settlement. A close can be verified
against real Core state rather than trusting off chain data.

### What fits the existing design

- **`cloid` is a 128 bit field the caller controls.** Action ID 1 (limit order) takes
  `cloid` as `uint128`, where 0 means none. That is a natural place for a commitment, so an order
  can be bound to a note without revealing its owner.
- **Note metadata needs no circuit change**, provided it is only client side bookkeeping. The
  existing `encryptedNoteData[n][4]` payload has room, and the commitment stays
  `Poseidon(assetId, owner, value)`. A circuit change is only required if the metadata must be
  constrained, for example proving in circuit that the closer owns the position.
- **Positions belong to the calling contract's Core account.** CoreWriter sends actions on behalf of
  the caller, which under `delegatecall` is the AdaptorHandler. So a position is publicly the pool's,
  which is the intended privacy model.

### Three obstacles, in order of difficulty

1. **Orders are asynchronous; the adaptor interface is not.**
   `handleAssets(AssetAmount[], bytes) returns (AssetAmount[])` is synchronous and returns token
   amounts, and `_receivePubAssets` then pulls those tokens and mints commitments. A CoreWriter order
   emits a log, is deliberately delayed a few seconds to remove any latency advantage over the L1
   mempool, and fills later at a price not known when the call returns. Nothing comes back in the
   same transaction. This needs a two phase adaptor, open then settle on close, which touches
   `ShieldedTransactionLogic` rather than only adding a file under `src/adaptors/`.

2. **One Core account holds one position per asset.** Isolated versus cross margin controls margin
   allocation, not multiplicity. Two users going long the same asset through one account net into a
   single position. Sub accounts appear in action 13 (`Send asset`, which takes a `subAccount`) and
   action 16 (`Set abstraction`), but the documentation consulted does not say whether a contract can
   create and control them.

3. **Value must cross from HyperEVM to HyperCore.** The pool holds ERC20s on the EVM while margin
   lives on Core. This bridge is untouched, and is the piece behind the original "HyperEVM to
   HyperCore" difficulty.

### The question that decides the architecture

**Can a contract create and control HyperCore sub accounts?**

- **If yes:** one sub account per position gives genuine isolation, one user's liquidation cannot
  touch another's, and the pool remains the visible funder so user identity stays hidden.
- **If no:** positions must be pooled, and notes represent pro rata shares of a single aggregate
  position per asset and direction. This is the same shape as the Morpho vault share note that
  already works. It gives a stronger anonymity set because users genuinely share a position, but
  users cannot choose independent size or entry. It is a shielded perp vault rather than private
  individual positions.

Resolve that before designing anything else. A related question worth settling at the same time is
liquidation: if a pooled position is liquidated, the behaviour of the notes claiming it is a design
decision, not an implementation detail.

### One thing not to assume

Encrypting order metadata hides the link between user and position. It does not hide the position.
HyperCore positions are public, including size, direction, entry and liquidation price. At low
volume a position is a near unique fingerprint, so correlation between pool activity and position
opens is the residual leak, and it is not addressed by anything in the note.
