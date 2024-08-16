// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolTransferTest is PoolTest {
    function setUp() public {
        _setUp();
        _makePreDeposit();
    }

    function test_transferWithoutFee() external {
        uint256 balance1 = token1.balanceOf(address(pool));
        ZTransaction memory ztx = _loadShieldedTransaction(
            "transfer_500_weth_without_fee"
        );
        _runExpectedTx(ztx);
        assertEq(token1.balanceOf(address(pool)), balance1);
    }

    function test_transferWithFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        ZTransaction memory ztx = _loadShieldedTransaction(
            "transfer_500_weth_with_weth_fee"
        );

        uint96 feeValue = uint96(ztx.feeData);
        address paymaster = address(bytes20(bytes32(ztx.feeData)));
        _runExpectedTx(ztx);

        vm.prank(paymaster);
        uint256 paymasterFee = pool.getCollectedPaymasterFee(
            asset1.id,
            paymaster
        );
        assertEq(token1.balanceOf(address(pool)), balance1);
        assertEq(paymasterFee, feeValue);
    }

    function test_revertOnDoubleSpendTransfer() external {
        ZTransaction memory ztx = _loadShieldedTransaction(
            "transfer_500_weth_without_fee"
        );
        pool.transact(ztx);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DoubleSpend.selector,
                ztx.nullifiers[0]
            )
        );
        pool.transact(ztx);
    }
}
