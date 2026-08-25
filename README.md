# Veilnyx v1 Protocol

Smart contracts for the Veilnyx v1 protocol.

## Overview

Veilnyx is a privacy protocol with built-in compliance, enabled by Selective De-Anonymization, Zero-Knowledge (ZK), and Multi-Party Computation (MPC).

**Key features:**
- Multi-asset privacy pool with shielded deposits, withdrawals, and P2P transfers
- Gas fees payable in any supported asset
- Compliance via Threshold privacy (Revoker + Guardian network)
- Adaptor system for DeFi integrations (Aave, Lido, Morpho, Uniswap, etc.)

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) — Solidity build and test framework
- [pnpm](https://pnpm.io/) — Node package manager
- Node.js ≥ 18

## Setup

```bash
pnpm install
```

Copy `.env.example` to `.env` and fill in the required RPC URLs and private keys.

## Build

```bash
pnpm build
# or
forge build
```

## Testing

### Fixture generation (required before running shielded tx dependent tests)
#### <span style="color: green">All fixtures have been updated. This step can be skipped.</span>
The majority of pool and adaptor tests rely on pre-generated ZK proof fixtures. These fixtures encode valid shielded transactions (deposits, transfers, adaptor calls) and must be regenerated whenever the SDK or circuit changes.

```bash
pnpm test:prepare
```

This runs `test/fixtures/scripts/index.ts` which generates encoded `ShieldedTransaction` fixtures under `test/fixtures/data/`. The script uses the `@veilnyx-sdk/core` SDK to produce real ZK proofs — expect it to take a few minutes.

> **Note:** The fixture generation script is selective. Open `test/fixtures/scripts/index.ts` to see which fixture groups are active and uncomment those you need. We have updated all tx fixtures, so running this should not be required.

### Run all tests
Running tests on Ethereum Mainnet fork is required for DeFi adaptor tests to work, since not all DeFi protocols are deployed on testnet. 

```bash
pnpm test
# or
source .env && forge test --fork-url $RPC_ETHEREUM_MAINNET
```

### Run a specific test file

```bash
forge test --match-contract PoolDepositTest -vvv
```

### Run a specific test

```bash
forge test --match-test testDeposit -vvv
```

### Fork tests (DeFi adaptor tests)

Adaptor tests (e.g. Aave, Lido) require a mainnet fork and will be skipped automatically when run without one. Pass the relevant RPC URL via `--fork-url`:

```bash
source .env && forge test --match-contract AaveAdaptorTest --fork-url "$RPC_ETHEREUM_MAINNET" -vvv
```

## Test structure

| Directory | Coverage |
|---|---|
| `test/pool/` | Core pool operations: deposits, withdrawals, transfers, adaptor calls, reentrancy |
| `test/adapters/` | DeFi adaptor integrations (require fork) |
| `test/integration/` | ERC-4337 account abstraction flow |
| `test/*.t.sol` | Unit tests for libraries and peripheral contracts |

### Test Coverage
```bash
source .env && forge coverage --no-match-coverage "(script|test)/.*" --fork-url $RPC_ETHEREUM_MAINNET --report lcov --report summary
```
#### Pre-generated coverage report available at: 
`v1-protocol/test/report/coverage.txt`****

## Deployment

Scripts live in `script/`. Deployments use Hardhat for network configuration and Forge for script execution.

```bash
# Deploy core protocol + adaptor handler (Sepolia)
pnpm deployCoreWithAdp:sepolia

# Deploy with proof aggregation infrastructure (Sepolia)
pnpm deployCoreWithProofAggrInfra:sepolia
```

### Roles & Actors
| Role | Privileges | Restrictions |
|------|-----------|--------------|
| Admin | 1. Can upgrade the implementation logic <br> 2. Can pause protocol operations <br> 3. Add asset support <br> 4. Add external protocol adaptor support <br> 5. Register new revokers and modify existing revoker's status <br> 6. Withdraw protocol fees <br> 7. Set and update protocol fees <br> 8. Update verification tracker service <br> 9. Assign and transfer the Verifier Manager role | Cannot transact |
| Verifier Manager | 1. Add new transaction verifiers <br> 2. Remove existing transaction verifiers <br> 3. Update the address verifier <br> 4. Update the tree update verifier | Cannot upgrade, pause, or perform any Pool-level admin ops. Role is assigned by the Admin |
| User | Can transact: deposit, transfer, withdraw, call external protocols privately | Cannot control protocol level ops |
| Revoker | Can revoke transaction | Cannot decrypt tx without the threshold no. of permissions received from the guardian network |
| Guardian | Can contribute to a revoke request by providing cryptographic permission | Cannot decrypt tx alone 

## Documentation
[Veilnyx Docs](http://veilnyx.gitbook.io/)

[Paymaster fee quoting](docs/paymaster-fee-quoting.md)

---

## ⚠️ CRITICAL: Upgrade Safety Warning

### 1. DO NOT Modify EIP-712 Domain Parameters

> **DO NOT MODIFY THE EIP-712 DOMAIN NAME OR VERSION WHEN UPGRADING THE POOL CONTRACT**

Changing the `EIP712_DOMAIN_NAME` or `EIP712_DOMAIN_VERSION` during a contract upgrade will **permanently break all existing shielded accounts**.

### Why This Is Critical

The shielded account derivation process uses the EIP-712 signature as a **seed** to generate the user's shielded account and all child accounts. The signature is derived from:

1. The EIP-712 domain separator (includes `name` and `version`)
2. The user's wallet signature

If the domain name or version changes:
-  The domain separator changes
-  The same wallet signature produces a **different** shielded account
-  Users **permanently lose access** to their original shielded accounts
-  **All funds in those accounts become irrecoverable, unless another upgrade reverts the EIP712 domain and version changes**

---

### 2. DO NOT Reinitialize Merkle Trees

> **DO NOT CALL `init()` ON THE ADDRESS TREE OR COMMITMENT TREE DURING UPGRADES**

Reinitializing the Merkle trees will **corrupt the root history and invalidate existing commitment notes**.

#### Why This Is Critical

The `MerkleTreeLogic.init()` and `QueuedMerkleTreeLogic.init()` functions:

1. Overwrite `roots[0]` with the empty tree root
2. Reset `lastSubtrees` array to zero values
3. Reset `zeroes` array

This causes:
- Historical roots stored at index 0 are lost
- `isKnownRoot()` returns `false` for valid historical roots
- **Existing commitment notes become unspendable** - users cannot prove membership against corrupted roots
- **Funds locked in affected commitments are irrecoverable**

---

### Safe Upgrade Pattern

When creating a `reinitializer` function for upgrades:

```solidity
// ✅ SAFE - Do NOT reinitialize EIP712 or Merkle trees
function initializeV2(address newParam) external reinitializer(2) {
    someNewVariable = newParam;
    // DO NOT call __EIP712_init()
    // DO NOT call _addressTree.init()
    // DO NOT call _commitmentTree.init()
}

// ❌ DANGEROUS - Never do this
function initializeV2() external reinitializer(2) {
    __EIP712_init("NewName", "2");           // BREAKS ALL SHIELDED ACCOUNTS
    _addressTree.init(depth, hasher);         // CORRUPTS ADDRESS TREE
    _commitmentTree.init(depth, size, ...);   // CORRUPTS COMMITMENT TREE
}
```

---

### Summary

| Action | Result |
|--------|--------|
| Change `EIP712_DOMAIN_NAME` | 🔴 All shielded accounts invalidated |
| Change `EIP712_DOMAIN_VERSION` | 🔴 All shielded accounts invalidated |
| Reinitialize `_addressTree` | 🔴 Address proofs may fail |
| Reinitialize `_commitmentTree` | 🔴 Existing commitment notes become unspendable |
| Keep all above unchanged | ✅ Full backward compatibility |

---



