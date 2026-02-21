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
