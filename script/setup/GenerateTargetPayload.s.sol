// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {Convertor} from "src/core/Convertor.sol";
import {Pool} from "src/core/Pool.sol";

/// @dev Static script that generates the `targetPayload` bytes for convert txns or any other purpose (if required).
/// @dev The components to be encoded are static and should be updated as required.
contract GenerateTargetPayload is Script {
    function run() external pure returns (bytes memory) {
        bytes memory swapOutPayloadForConvertZTx = abi.encode(
            65538, // USDC
            address(0), // beneficiary: Any EVM address or address(0) which will send out tokens to Convertor.sol. Then the Convertor.sol transfers them to the Pool.
            0
        );
        return swapOutPayloadForConvertZTx;
    }
}
