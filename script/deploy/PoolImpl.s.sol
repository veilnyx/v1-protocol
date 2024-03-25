// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseScript} from "../BaseScript.sol";
import {Pool} from "src/core/Pool.sol";

contract PoolImplDeploy is BaseScript {
    function run() external broadcast {
        new Pool();
    }
}
