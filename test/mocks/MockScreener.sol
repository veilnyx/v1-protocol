// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IScreener} from "src/interfaces/IScreener.sol";

contract MockScreener is IScreener {
    function isSanctioned(address) public pure override returns (bool) {
        return false;
    }
}
