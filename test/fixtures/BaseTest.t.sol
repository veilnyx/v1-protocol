// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ZTransactionType, ZTransaction} from "src/libraries/ZTransaction.sol";
import {Fixture, FixtureLib} from "test/fixtures/Fixture.sol";

abstract contract BaseTest is Test {
    Fixture public fixture;

    constructor() {
        fixture = FixtureLib.load(vm);
    }

    function _loadZTx(
        string memory name
    ) internal view returns (ZTransaction memory) {
        return FixtureLib.loadZTx(name, vm);
    }
}
