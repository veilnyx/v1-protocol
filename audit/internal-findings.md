# Internal Audit Findings

## Slither Findings

## **Finding 1:**
### [L-01] `arbitrary-send-eth`

**File:** `src/adaptors/RocketPoolAdaptor.sol`

**Finding:** Slither flagged `RocketPoolAdaptor.sol` for sending ETH/rETH to arbitrary contract `rocketSwapRouter`.

**Code:**
```solidity
rocketSwapRouter.swapTo{value: stakeValue}(
            uniswapPortion,
            balancerPortion,
            minTokensOut,
            minTokensOut
        );
```

```solidity
IERC20(rETH).forceApprove(address(rocketSwapRouter), unstakeValue);
rocketSwapRouter.swapFrom(
            uniswapPortion,
            balancerPortion,
            minTokensOut,
            minTokensOut,
            unstakeValue
        );
```
**Status:** Acknowledged / Fixed

**Justification:**
1. Same as Finding 2 justification but non-explicit.
2. The `rocketSwapRouter` address is now made immutable in the adaptor contract, making it part of the audit process, rather than auditing the initialisation step.
3. An explicit view function `getRocketSwapRouterAddress()` has been added to return the RocketPool's swap router contract address.

## **Finding 2:**
### [I-01] controlled-delegatecall

**File:** `src/core/AdaptorHandler.sol`

**Finding:** Slither flagged a controlled delegate call vulnerability in the `handleAdaptor` function where `target.delegatecall()` is invoked with a user-supplied `target` address.

**Code:**
```solidity
(bool success, bytes memory res) = target.delegatecall(
    abi.encodeCall(
        IAdaptor.handleAssets,
        (inAssetIds, inValues, targetPayload)
    )
);
```

**Status:** Acknowledged / Fix not required

**Justification:**

This finding is a **false positive** in the context of our protocol's security model:

1. **Whitelisted Adapters Only:** The `target` address is not arbitrary—it must be a whitelisted adapter. Only adapters that have been explicitly approved can be called through this mechanism.

2. **Multi-Sig Governance:** Adapter whitelisting is controlled by the protocol's multi-sig community. Adding a new adapter requires approval from multiple trusted signers, ensuring no single party can introduce a malicious adapter.

3. **Mandatory Audit Process:** Every adapter undergoes a thorough security audit before being whitelisted. This ensures that any code executed via `delegatecall` has been reviewed for vulnerabilities and malicious behavior.

4. **Trusted Execution Context:** Since adapters are audited and approved by the governance multi-sig, the delegate call to these contracts is considered safe within our trust model.

**Conclusion:** A delegate call to an external adapter that has been whitelisted by the multi-sig community and audited is acceptable and does not pose a security risk within our protocol's threat model.

## **Finding 3:**
### [M-01] Missing access control on `AdaptorHandler.handleAdaptor`

**File:** `src/core/AdaptorHandler.sol`

**Finding:** `handleAdaptor` had no caller restriction — any address could invoke it directly, bypassing the Pool entirely. This violates the principle of least privilege: the function is only ever intended to be called by the Pool during a shielded transaction, yet it was exposed to the entire call surface.

**Code (before fix):**
```solidity
// No access control
function handleAdaptor(
    address target,
    PubAsset[] calldata pubAssets,
    bytes calldata targetPayload
) external payable returns (PubAsset[] memory) { ... }
```

**Secondary concern — reentrancy via `balanceOf` / `forceApprove` (low risk):**

After the `delegatecall` completes, `handleAdaptor` calls `balanceOf()` and `forceApprove()` on each output asset address. These are external calls to the token contract and represent potential reentrancy vectors.

**Attack vectors:**

1. **Malicious ERC-20 implementation:** Any external call can execute arbitrary code. A malicious token can override standard functions to re-enter the caller:

```solidity
// Malicious ERC20
contract MaliciousERC20 {
    mapping(address => uint256) public balances;
    address public targetContract;
    bool public attacking;

    // Standard-looking balanceOf but with malicious re-entry
    function balanceOf(address account) external returns (uint256) {
        if (!attacking && account == targetContract) {
            attacking = true;
            // Re-enter AdaptorHandler before returning balance
            (bool success, ) = targetContract.call(
                abi.encodeWithSignature(
                    "handleAdaptor(address,(uint24,uint224)[],bytes)",
                    // ... malicious parameters
                )
            );
        }
        return balances[account];
    }

    // approve/forceApprove can also re-enter
    function approve(address spender, uint256 amount) external returns (bool) {
        if (!attacking) {
            attacking = true;
            // Malicious re-entry here as well
            (bool success, ) = targetContract.call(...);
        }
        // ... standard logic
        return true;
    }
}
```

2. **ERC-777 style tokens with hooks:** Tokens implementing ERC-777 have built-in `tokensToSend` and `tokensReceived` hooks that are automatically triggered during transfers. These hooks can execute arbitrary code and re-enter the calling contract. Similar risks exist with ERC-1363 (`onTransferReceived`) and ERC-677 (`transferAndCall`).

**Risk assessment — low in practice because:**
- All asset addresses come from `IPool(msg.sender).getAsset()`, which only returns active whitelisted assets.
- Whitelisted assets are vetted and approved by the multi-sig community.
- Any token whitelisted goes through mandatory audit process, reducing chances of malicious token implementations.
- Standard ERC-20 implementations (OpenZeppelin, Solmate) do not contain malicious logic.

**Note on `forceApprove` + direct call:** An attacker calling `handleAdaptor` directly would only receive approval (`forceApprove(msg.sender, ...)`) for tokens that were already present in `AdaptorHandler` from a prior adaptor operation. They cannot steal other users' funds because the Pool controls asset flow into the contract. The direct-call attack is therefore not economically profitable, but remains a privilege violation.

**Status:** Fixed

**Fix:**
1. An `onlyPool` modifier restricts `handleAdaptor(..)` to calls from the registered `veilnyxPool` address, enforcing least privilege.
2. `setVeilnyxPool(..)` is restricted to `onlyOwner` (OZ `Ownable`) to prevent front-running the pool registration on deployment.
3. `AdaptorHandler` contract inherits OZ `ReentrancyGuard`; `handleAdaptor(..)` carries `nonReentrant` as a defence-in-depth measure against the low-risk hook reentrancy scenario.

## **Finding 4:**
### [L-02] `PoolStorage.version` is never initialized

**File:** `src/base/PoolStorage.sol`

**Finding:** `uint64 public version` is declared but never set. `getVeilnyxVersion()` always returns `0`.

**Status:** Fixed

**Fix:** Added `setVersion(uint64 version_)` function in `Pool.sol` with `onlyOwner` access control. The deploy and upgrade scripts now call this function to set the protocol version.

**Note on EIP-712 versioning:** Although EIP-712 includes a `version` field in the domain separator, we explicitly **do not use it for protocol versioning**. Changing the EIP-712 domain name or version would invalidate all existing signatures and permanently break all shielded accounts, as the signature is used as a seed for shielded account derivation.

See [README.md — ⚠️ CRITICAL: Upgrade Safety Warning](../README.md#%EF%B8%8F-critical-upgrade-safety-warning) for full details on upgrade constraints.

---

## **Finding 5:**
### [I-02] `payable` modifier unnecessary on `IAdaptor.handleAssets`

**File:** `src/interfaces/IAdaptor.sol`

**Finding:** The `payable` modifier on `handleAssets` function in `IAdaptor` is unnecessary since all adaptors are invoked via `delegatecall` from `AdaptorHandler.sol`.

**Code:**
```solidity
function handleAssets(
    uint24[] calldata inAssetIds,
    uint256[] calldata inValues,
    bytes calldata payload
)
    external
    payable  // <-- unnecessary
    virtual
    returns (uint24[] memory outAssetIds, uint256[] memory outValues);
```

**Explanation:**
- When using `delegatecall`, the adaptor code executes in the context of `AdaptorHandler`
- `msg.value` from the original call is already accessible without the `payable` modifier
- No ETH is actually "received" by the adaptor contract itself
- The `payable` modifier was added to enable direct function calls during testing

**Status:** Acknowledged

**Recommendation:**
1. Remove `payable` from `IAdaptor.handleAssets` and all implementing adaptor contracts after audit completion
2. For test cases that require direct ETH transfers to adaptor contracts, activate the `receive()` function during test setup:
   ```solidity
   receive() external payable {}
   ```

**Affected Files:**
- `src/interfaces/IAdaptor.sol`
- `src/adaptors/aave-v3/AaveV3Adaptor.sol`
- `src/adaptors/lido/LidoAdaptor.sol`
- `src/adaptors/rocket-pool/RocketPoolAdaptor.sol`
- `src/adaptors/uniswap/UniswapAdaptor.sol`
- `src/adaptors/morpho/MorphoAdaptor.sol`

---

## **Finding 6:**
### [M-02] Inverted `NCoins` assignment in `CurveNGAdaptor.getLPTokenCount`

**File:** `src/adaptors/curveNG/CurveNGAdaptor.sol`

**Finding:** The `try/catch` block that detects pool size in `getLPTokenCount` assigns `NCoins` with inverted values relative to the correct logic in `handleAssets`. A successful call to `coins(2)` proves the pool has at least 3 coins, but `getLPTokenCount` assigns `NCoins = 2` on success and `NCoins = 3` on revert — the opposite of what is correct.

**Code (buggy):**
```solidity
// getLPTokenCount — WRONG
try ICurvePool(pool).coins(2) returns (address) {
    NCoins = 2; // coins(2) exists → pool has 3 coins, not 2
} catch {
    NCoins = 3; // coins(2) reverts → pool has 2 coins, not 3
}
```

**Reference (correct logic in `handleAssets`):**
```solidity
try ICurvePool(decodedPayload.curvePool).coins(2) returns (address) {
    NCoins = 3; // correct
} catch {
    NCoins = 2; // correct
}
```

**Impact:** `getLPTokenCount` will always route 2-coin pools through `_calcLPTokens3CoinPool` and 3-coin pools through `_calcLPTokens2CoinPool`, producing incorrect LP token estimates for every pool type. Any off-chain or on-chain caller relying on this view function for slippage calculation or deposit sizing will receive wrong values.

**Status:** Open — fix pending

---

## **Finding 7:**
### [L-03] Bare `ERC20.approve()` used instead of `SafeERC20.forceApprove()` across adaptors and Gateway

**Files:**
- `src/adaptors/aave-v3/AaveV3Adaptor.sol`
- `src/adaptors/ethena/EthenaAdaptor.sol`
- `src/adaptors/lido/LidoAdaptor.sol`
- `src/core/Gateway.sol`

**Finding:** Multiple contracts called `IERC20.approve()` directly. Tokens with non-standard `approve` implementations (e.g. USDT, which requires resetting to 0 before re-approving) will revert, silently bricking adaptor operations for those assets.

**Status:** Fixed — all instances replaced with `SafeERC20.forceApprove()`.

---

## **Finding 8:**
### [L-04] `shadowing-local` — local variables shadow inherited storage variables

**Files:**
- `src/core/MemPool.sol`
- `src/core/Pool.sol`

**Finding:** Two local variables shadowed inherited storage state:

1. `Mempool._handleDepositedAssets(address pool, ...)` — the `pool` parameter shadowed `MempoolStorage.pool`, risking confusion over which `pool` address was being used.
2. `Pool.updateEIP712Domain(string version, ...)` — the `version` parameter shadowed `PoolStorage.version`, creating ambiguity between the EIP-712 domain version string and the protocol version integer.

**Status:** Fixed.

**Fix:**
1. The `pool` parameter was removed from `_handleDepositedAssets`; the function now references the `MempoolStorage.pool` storage variable directly.
2. `updateEIP712Domain` was removed; the new `setVersion(uint64 version_)` function uses a trailing underscore convention to avoid shadowing `PoolStorage.version`.

---

## **Finding 9:**
### [L-05] Missing zero-address checks in constructors of core contracts

**Files:**
- `src/core/Hasher.sol`
- `src/core/Verifier.sol`
- `src/core/Gateway.sol`
- `src/core/Paymaster.sol`

**Finding:** Constructors across all four core contracts assigned critical immutable addresses without validating against `address(0)`. A deployment misconfiguration (e.g., a missing argument in a deploy script) would silently produce a permanently broken contract with no upgrade path.

| Contract | Parameters at risk |
|---|---|
| `Hasher` | `poseidonT3`, `poseidonT4`, `poseidonT5` |
| `Verifier` | `addressVerifier`, `treeUpdateVerifier`, each `txvInfos[i].addr` |
| `Gateway` | `entryPoint_`, `wToken_`, `pool_`, `mempool_` |
| `Paymaster` | `entryPoint_`, `sender_`, `pool_` |

**Status:** Fixed — `ZeroAddress()` custom error added to each contract; constructor guards revert on any zero address before state is written.

---