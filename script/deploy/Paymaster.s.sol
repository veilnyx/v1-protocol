// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Paymaster} from "src/core/Paymaster.sol";
import {BaseScript} from "../BaseScript.sol";

contract PaymasterDeploy is BaseScript {
    function run() external broadcast {
        address entryPoint = _config.entryPoint();
        address gateway = _getContract("Gateway");
        new Paymaster(entryPoint, gateway);
    }
}
