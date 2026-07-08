// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Screener} from "src/core/Screener.sol";
import {BaseScript} from "../BaseScript.sol";

contract ScreenerDeploy is BaseScript {
    function run() external broadcast {
        address sanctionsList = _config.sanctionsList();
        new Screener(sanctionsList);
    }
}
