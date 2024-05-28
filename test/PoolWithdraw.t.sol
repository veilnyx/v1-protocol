// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";

contract PoolWithdrawTest is PoolTest {
    Pool internal _pool;

    function setUp() public {
        _initFixture();
        _makeInitialDeposit();
    }

    function test_withdraw500WethWithoutFee() public {
        ZTransaction memory ztx = _loadZTx("withdraw_500_weth_without_fee");

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(ztx.nullifiers[i]);
        }

        pool.transact(ztx);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        }
    }

    function test_withdraw500WethWithWethFee() public {
        ZTransaction memory ztx = _loadZTx("withdraw_500_weth_with_weth_fee");

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(ztx.nullifiers[i]);
        }

        pool.transact(ztx);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        }
    }
}
