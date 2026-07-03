// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

contract JsFFI is Test {
    function runScript(
        string memory scriptName,
        string memory args
    ) public returns (bytes memory result) {
        string[] memory inputs = new string[](8);

        // build ffi command string
        inputs[0] = "npm";
        inputs[1] = "--silent";
        inputs[2] = "--prefix";
        inputs[3] = "./test/js-ffi";
        inputs[4] = "run";
        inputs[5] = scriptName;
        inputs[6] = "--";
        inputs[7] = args;
        result = vm.ffi(inputs);
    }
}
