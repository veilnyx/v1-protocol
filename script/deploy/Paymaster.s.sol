// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Paymaster} from "src/core/Paymaster.sol";
import {BaseScript} from "../BaseScript.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract PaymasterDeploy is BaseScript {
    function run() external broadcast {
        address entryPoint = _config.entryPoint();
        address gateway = _getContract("Gateway");
        address pool = _getContract("Pool");
        new Paymaster(IEntryPoint(entryPoint), gateway, IPool(pool));
    }
}
