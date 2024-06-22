// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";

contract PoolInitTest is PoolTest {
    function setUp() public {
        _initFixture();
    }

    function test_correctParameters() public view {
        address verifier_ = pool.verifier();
        address adaptorHandler_ = pool.adaptorHandler();

        assertEq(verifier_, address(verifier));
        assertEq(adaptorHandler_, address(adaptorHandler));
    }
}
