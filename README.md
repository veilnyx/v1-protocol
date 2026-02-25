# v1 Protocol

Smart contracts for Veilnyx v1 protocol

## Overview
Veilnyx is a privacy protocol with built-in compliance, enabled by Selective De-Anonymization, Zero-Knowledge (ZK), and Multi-Party Computation (MPC).

### Key Features
1. Multi-asset privacy pool
2. Fully private P-2-P transfers
3. Gas fee in any asset of choice ( should be supported by the protocol )
4. Involuntary Compliance protected by Threshold privacy (Revoker + Guardian network)
5. Voluntary compliance
6. Reduced proof verification costs through proof aggregation (developed but not shipping)

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
- ❌ The domain separator changes
- ❌ The same wallet signature produces a **different** shielded account
- ❌ Users **permanently lose access** to their original shielded accounts
- ❌ **All funds in those accounts become irrecoverable, unless another upgrade reverts the EIP712 domain and version changes**
#### Why This Is Critical

The shielded account derivation process uses the EIP-712 signature as a **seed** to generate the user's shielded account and all child accounts. The signature is derived from:

1. The EIP-712 domain separator (includes `name` and `version`)
2. The user's wallet signature

If the domain name or version changes:
- ❌ The domain separator changes
- ❌ The same wallet signature produces a **different** shielded account
- ❌ Users **permanently lose access** to their original shielded accounts
- ❌ **All funds in those accounts become irrecoverable**, unless another upgrade reverts the EIP712 domain and version changes

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
- ❌ Historical roots stored at index 0 are lost
- ❌ `isKnownRoot()` returns `false` for valid historical roots
- ❌ **Existing commitment notes become unspendable** - users cannot prove membership against corrupted roots
- ❌ **Funds locked in affected commitments are irrecoverable**

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



