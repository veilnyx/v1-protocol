// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseScript} from "../BaseScript.sol";

import {Convertor} from "src/core/Convertor.sol";

contract ConvertorDeploy is BaseScript {
    function run() external broadcast {
        new Convertor();
    }
}
