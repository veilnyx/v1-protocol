// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolWithdrawTest is PoolTest {
    function setUp() public {
        _setUp();
        _makePreDeposit();
    }

    function test_withdrawWithoutFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_500_weth_without_fee"
        );

        uint256 feeBps = pool.withdrawFeeBps();

        uint224 withdrawAmt = uint224(stx.pubAssets[0]);
        uint256 balanceAfter = balance1 -
            withdrawAmt +
            (withdrawAmt * feeBps) /
            10000;

        _runExpectedTx(stx);

        assertEq(token1.balanceOf(address(pool)), balanceAfter);
    }

    function test_withdrawWithFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        uint224 withdrawAmt = uint224(stx.pubAssets[0]);
        uint256 feeBps = pool.withdrawFeeBps();
        uint96 feeValue = uint96(stx.feeData);

        _runExpectedTx(stx);

        uint256 expectedBalPostWithdraw = balance1 -
            withdrawAmt +
            feeValue +
            ((withdrawAmt - feeValue) * feeBps) /
            10000;

        assertEq(token1.balanceOf(address(pool)), expectedBalPostWithdraw);
    }
}
