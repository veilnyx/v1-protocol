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
