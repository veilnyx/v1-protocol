// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";

contract AdaptorHandlerDeploy is BaseScript {
    function run() external broadcast {
        new AdaptorHandler();
    }
}
