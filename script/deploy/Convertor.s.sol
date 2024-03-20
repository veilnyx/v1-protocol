// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {DeployScript} from "./DeployScript.sol";

import {Convertor} from "src/core/Convertor.sol";

contract ConvertorDeploy is DeployScript {
    function _deploy() internal override {
        new Convertor();
    }
}
