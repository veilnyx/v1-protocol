# Paymaster fee quoting

The ERC-4337 EntryPoint reserves the paymaster's worst-case native-token prefund:

$$
\text{maxCost}=\text{requiredGas}\times\text{maxFeePerGas}
$$

This protects paymaster solvency, but it is not the amount a shielded user must commit as `feeValue`. During validation, the paymaster scales that prefund to the gas price applicable in the validation block:

$$
\text{effectiveGasPrice}=\min(\text{maxFeePerGas},\text{maxPriorityFeePerGas}+\text{block.basefee})
$$

$$
\text{requiredNativeFee}=\text{maxCost}\times\frac{\text{effectiveGasPrice}}{\text{maxFeePerGas}}
$$

Account-abstraction's legacy rule is preserved: when `maxFeePerGas == maxPriorityFeePerGas`, the effective gas price is `maxFeePerGas`.

The resulting native-token amount is converted to `feeAssetId` with the configured Chainlink feed and compared with the proof-bound `feeValue`. EntryPoint prefunding and refund accounting remain unchanged.

## SDK quotes

Before signing and proving, clients should:

1. Calculate EntryPoint's worst-case `maxCost` from the final UserOperation.
2. Fetch the latest block base fee.
3. Call the SDK's `quoteUserOpGasCostWithLatestBaseFee()` helper.
4. Pass the result as `TransactionOptions.userOpFeeQuoteEth` so the converted fee is committed into the shielded transaction.

The SDK applies 5,000 basis points (50%) of headroom by default and caps the buffered gas price at `maxFeePerGas`. Callers can set a different non-negative `headroomBps` value.

Because `feeValue` is part of the signed and proved transaction, it cannot be adjusted after proof generation:

- If the inclusion-block requirement is within the quote, validation succeeds.
- If base fee and/or the fee-asset conversion price rises beyond the quote, paymaster validation reverts with `InsufficientFee`.
- If the inclusion-block requirement is lower, unused quote headroom remains charged; this design does not issue a private refund.
