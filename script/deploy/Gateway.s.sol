// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Gateway} from "src/core/Gateway.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {BaseScript} from "../BaseScript.sol";

contract GatewayDeploy is BaseScript {
    function run() external broadcast {
        address entryPoint = _config.entryPoint();
        address nativeWToken = _config.nativeWToken();
        address pool = _getContract("PoolProxy");

        new Gateway(
            IEntryPoint(entryPoint),
            IWToken(nativeWToken),
            IPool(pool)
        );
    }
}
