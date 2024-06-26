// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {JsFFI} from "./JsFFI.sol";

struct ShieldedAccount {
    uint256 seed;
    address pubAddress;
    uint256 rootAddress;
}
