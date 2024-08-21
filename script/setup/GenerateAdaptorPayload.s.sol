// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {Pool} from "src/core/Pool.sol";

/// @dev Static script that generates the `targetPayload` bytes for convert txns or any other purpose (if required).
/// @dev The components to be encoded are static and should be updated as required.
contract GenerateAdaptorPayload is Script {
    function run() external pure returns (bytes memory) {
        bytes memory swapOutPayloadForConvertStx = abi.encode(
            uint24(65541), // USDC
            address(0), // beneficiary: Any EVM address or address(0) which will send out tokens to AdaptorHandler.sol. Then the AdaptorHandler.sol transfers them to the Pool.
            uint256(0) // minOut (for uniswap slippage protection, set to 0 for now)
        );
        return swapOutPayloadForConvertStx;
    }
}
