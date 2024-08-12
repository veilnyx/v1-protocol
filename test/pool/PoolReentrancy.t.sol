// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockAttacker} from "test/mocks/MockAttacker.t.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PoolReentrancyTest is PoolTest {
    ZTransaction attackerWithdrawZtx;
    PoolTransactTest poolTransactTestHelper;
    MockAttacker attacker;
    uint256 attackerDeposit = 10 ether;

    function setUp() public {
        _setUp();
        // _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        // _approveAsset(asset1, address(pool), INITIAL_DEPOSIT);

        ZTransaction memory bulkDepositZtx = _loadShieldedTransaction(
            "deposit_1000_weth_usdc_without_fee"
        );
        pool.transact(bulkDepositZtx);

        attackerWithdrawZtx = _loadShieldedTransaction(
            "withdraw_500_weth_without_fee_to_mock_attacker"
        ); // `to` address will be that of the attacker contract which will perform the reentrancy attack

        attacker = new MockAttacker(pool, attackerWithdrawZtx, token1); // will perform the reentrancy attack and test the revert
        console.log("Attacker address:", address(attacker));
    }

    function test_reentrancyAttack() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector,
                address(token1)
            )
        );
        pool.transact(attackerWithdrawZtx); // initiating the withdraw to attacker that will perform reentrancy attack

        assertEq(token1.balanceOf(address(attacker)), 0);
        // assertEq(token1.balanceOf(address(pool)), INITIAL_DEPOSIT);
    }
}
