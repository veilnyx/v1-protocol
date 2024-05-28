// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";

contract PoolDepositTest is PoolTest {
    function setUp() public {
        _initFixture();
    }

    function test_deposit1000WethAndUsdc() public {
        _mintAsset(asset1, address(this), 1000 ether);
        _mintAsset(asset2, address(this), 1000 ether);
        _approveAsset(asset1, address(pool), 1000 ether);
        _approveAsset(asset2, address(pool), 1000 ether);

        ZTransaction memory ztx = _loadZTx("deposit_1000_weth_usdc");
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
