// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {ZERO_LEAF} from "src/base/Constants.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

contract PoolDepositWithdrawTest is PoolTest {
    uint256 public constant ETH_SEPOLIA = 11155111;

    function setUp() public {
        _setUp();
    }

    function test_depositWithdraw_integration() public {
        if (block.chainid != ETH_SEPOLIA && block.chainid != 1) {
            vm.skip(true);
        }
        address testnet_weth = config.wToken();
        uint256 deposit = 2 ether;
        uint256 ethBalanceBefore = address(this).balance;

        uint256 poolBalanceBeforeDeposit = IWToken(testnet_weth).balanceOf(
            address(pool)
        );
        uint256 expectedPoolBalancePostDeposit = poolBalanceBeforeDeposit +
            deposit;

        vm.deal(address(this), ethBalanceBefore + deposit); // adding deposit to maintain the bal as `ethBalanceBefore`
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );
        pool.transact{value: deposit}(stx);

        // Pool should hold the wrapped 2 WETH and the caller's ETH balance
        // should have decreased by exactly `deposit`.
        assertEq(address(this).balance, ethBalanceBefore);
        assertEq(
            IWToken(testnet_weth).balanceOf(address(pool)),
            expectedPoolBalancePostDeposit
        );

        _processCommitmentTreeQueue();

        // Withdraw the deposited WETH back as ETH to check the full cycle works as expected
        uint256 withdrawalAmount = 1 ether;
        ShieldedTransaction memory stx2 = _loadShieldedTransaction(
            "withdraw_1_testnet_weth_without_fee"
        );

        // The withdrawal target is the shielded sender's public address encoded in the fixture,
        // not the test contract — extract it from the stx so we assert the right address.
        address withdrawTarget = address(bytes20(stx2.targetData));
        uint256 targetEthBefore = withdrawTarget.balance;

        pool.transact(stx2);

        uint256 feeBps = pool.withdrawFeeBps();
        uint256 protocolFee = (withdrawalAmount * feeBps) / 10000;
        uint256 expectedEthToTarget = withdrawalAmount - protocolFee;

        // Target receives native ETH (not WETH)
        assertEq(withdrawTarget.balance - targetEthBefore, expectedEthToTarget);
        assertEq(
            IWToken(testnet_weth).balanceOf(withdrawTarget),
            0,
            "target must receive ETH, not WETH"
        );

        // Pool WETH balance: deposit + initial - net_withdrawn; protocol fee stays as WETH
        assertEq(
            IWToken(testnet_weth).balanceOf(address(pool)),
            expectedPoolBalancePostDeposit - withdrawalAmount + protocolFee
        );
    }
}
