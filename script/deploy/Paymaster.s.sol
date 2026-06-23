// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Paymaster} from "src/core/Paymaster.sol";
import {BaseScript} from "../BaseScript.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

interface IPoolStaleness {
    function priceFeedStalenessThreshold() external view returns (uint256);
}

contract PaymasterDeploy is BaseScript {
    function run() external broadcast {
        address entryPoint = _config.entryPoint();
        address gateway = _getContract("Gateway");
        address pool = _getContract("Pool");
        // Bootstrap Paymaster staleness threshold from Pool's current value.
        // The owner can later adjust independently via setPriceStalenessThreshold().
        uint256 priceStaleness = IPoolStaleness(pool).priceFeedStalenessThreshold();
        new Paymaster(IEntryPoint(entryPoint), gateway, IPool(pool), priceStaleness);
    }
}
