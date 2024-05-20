// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseScript} from "../BaseScript.sol";
import {Paymaster} from "src/core/Paymaster.sol";

contract PaymasterDeploy is BaseScript {
    function run() external broadcast {
        address entryPoint = _config.entryPoint();
        address gateway = _getContract("Gateway");
        new Paymaster(entryPoint, gateway);
    }
}
