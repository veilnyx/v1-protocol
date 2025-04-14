// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {PreVerificationDetails} from "src/interfaces/IMempool.sol";

library NebraLib {
    /// @notice Generates a proof id for Nebra proof verification
    /// @dev Written in assembly because abi.encodePacked was causing stack too deep error due to large number of inputs (public inputs)
    function genNebraProofId(
        PreVerificationDetails memory preVerificationDetails
    ) public pure returns (bytes32) {
        // Pre-allocate memory for exact encoding pattern
        bytes memory encoded = new bytes(416); // circuit ID + 11 public inputs = 32 + 384 = 416 bytes

        assembly {
            let publicInputCount := 11
            let ptr := add(encoded, 32)

            // Store circuitId with proper padding
            mstore(ptr, mload(add(preVerificationDetails, 32)))
            ptr := add(ptr, 32)

            // Get publicInputs array pointer
            // Add 64 instead of 32 to skip over the bool field (32 bytes) and access circuitId
            let publicInputsPtr := mload(add(preVerificationDetails, 64))

            // Check array length (first 32 bytes of array contain length)
            let arrayLength := mload(publicInputsPtr)
            if iszero(eq(arrayLength, publicInputCount)) {
                revert(0, 0) // Revert if not exactly 16 inputs
            }

            // Skip array length prefix and copy inputs
            publicInputsPtr := add(publicInputsPtr, 32)
            for {
                let i := 0
            } lt(i, publicInputCount) {
                i := add(i, 1)
            } {
                mstore(ptr, mload(add(publicInputsPtr, mul(i, 32))))
                ptr := add(ptr, 32)
            }
        }

        return keccak256(encoded);
    }
}
