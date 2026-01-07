// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "../src/interfaces/IPool.sol";
import {PoolTest} from "./fixtures/PoolTest.sol";
import {Screener} from "../src/core/Screener.sol";

contract TestDepositAddrScreening is PoolTest {
    address chainAnalysisScreenerMainnetOracle =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;

    function setUp() public {
        _setUp();
        Screener chainAnalysisScreenerMainnet = new Screener(
            chainAnalysisScreenerMainnetOracle
        );
        pool.setScreener(address(chainAnalysisScreenerMainnet));
    }

    function test_depositAddrScreening() public {
        address sanctionedAddr = 0xd5ED34b52AC4ab84d8FA8A231a3218bbF01Ed510; // Example sanctioned address

        bool isSanctioned = pool.isDepositAddrSanctioned(sanctionedAddr);

        assertEq(isSanctioned, true);
    }
}
