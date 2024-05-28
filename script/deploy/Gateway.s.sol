// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";

import {Gateway} from "src/core/Gateway.sol";

contract GatewayDeploy is BaseScript {
    function run() external broadcast {
        address entryPoint = _config.entryPoint();
        address wToken = _config.wToken();
        address pool = _getContract("PoolProxy");
        new Gateway(entryPoint, wToken, pool);
    }
}
