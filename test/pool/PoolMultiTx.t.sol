// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolMultiTxTest is PoolTest {
    Pool internal _pool;
    PoolTransactTest poolTransactTestHelper;

    function setUp() public {
        _initFixture();
        _mintAsset(asset1, address(this), 1 ether);
        _approveAsset(asset1, address(pool), 1 ether);

        ZTransaction memory initialDepositZTrxn = _loadZTx("deposit_1_weth_without_fee"); // deposit setup

        pool.transact(initialDepositZTrxn);
    }

    function test_revertWhenSenderAttemptsToWithdrawPostTransfer() external {
        ZTransaction memory transferZTx = _loadZTx("transfer_1_weth_without_fee"); // actual ztx to test
        pool.transact(transferZTx);

        ZTransaction memory withdrawSameAmt = _loadZTx(
            "withdraw_1_weth_without_fee"
        );
        
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DoubleSpend.selector,
                withdrawSameAmt.nullifiers[0]
            )
        );
        pool.transact(withdrawSameAmt);
    }
}
