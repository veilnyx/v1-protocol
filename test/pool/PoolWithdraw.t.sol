// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {Fixture} from "test/fixtures/Fixture.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

contract PoolWithdrawTest is PoolTest {
    function setUp() public {
        _setUp();
        // _makePreDeposit();
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

    function test_withdrawPostBatchDeposit() public {
        _mintAsset(asset1, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);

        ShieldedTransaction memory depositStx = _loadShieldedTransaction(
            "batch_deposit"
        );
        _runExpectedTx(depositStx);
        _processCommitmentTreeQueue();

        uint256 withdrawAmt = 2 ether;
        uint256 fee = (withdrawAmt * pool.withdrawFeeBps()) / 10000; // (2e18 * 5) / 1e4 = 1e19/1e4 = 1e15
        uint256 expectedCreditAmt = withdrawAmt - fee; // 2e18 - 1e15

        ShieldedTransaction memory withdrawStx = _loadShieldedTransaction(
            "withdraw_2_weth_without_fee"
        );
        _runExpectedTx(withdrawStx);
        address receiver = fixture.receiver.pubAddress;
        uint256 receiverBal = IERC20(asset1.assetAddress).balanceOf(receiver);
        console2.log("Receiver bal post withdrawal:", receiverBal);

        assertEq(receiverBal, expectedCreditAmt);
    }
}
