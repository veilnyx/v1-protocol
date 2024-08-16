// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolWithdrawTest is PoolTest {
    function setUp() public {
        _setUp();
        _makePreDeposit();
    }

    function test_withdrawWithoutFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        ZTransaction memory ztx = _loadShieldedTransaction(
            "withdraw_500_weth_without_fee"
        );

        uint256 feeBps = pool.withdrawFeeBps();

        uint224 withdrawAmt = uint224(ztx.pubAssets[0]);
        uint256 balanceAfter = balance1 -
            withdrawAmt +
            (withdrawAmt * feeBps) /
            10000;

        _runExpectedTx(ztx);

        assertEq(token1.balanceOf(address(pool)), balanceAfter);
    }

    function test_withdrawWithFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));

        ZTransaction memory ztx = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        uint224 withdrawAmt = uint224(ztx.pubAssets[0]);
        uint256 feeBps = pool.withdrawFeeBps();
        uint96 feeValue = uint96(ztx.feeData);

        _runExpectedTx(ztx);

        uint256 expectedBalPostWithdraw = balance1 -
            withdrawAmt +
            feeValue +
            ((withdrawAmt - feeValue) * feeBps) /
            10000;

        assertEq(token1.balanceOf(address(pool)), expectedBalPostWithdraw);
    }
}
