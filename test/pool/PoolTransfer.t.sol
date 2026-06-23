// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolTransferTest is PoolTest {
    function setUp() public {
        _setUp();
        _makePreDeposit();
    }

    function test_debugQueueState() external view {
        (
            uint32 startIdx,
            uint32 endIdx,
            uint32 nextLeaf,
            uint8 queueSz,
            uint8 rootIdx
        ) = pool.getQueueRawState();
        console2.log("startIdx:", startIdx);
        console2.log("endIdx:", endIdx);
        console2.log("nextLeaf:", nextLeaf);
        console2.log("queueSz:", queueSz);
        console2.log("rootIdx:", rootIdx);
    }

    function test_transferWithoutFee() external {
        uint256 balance1 = token1.balanceOf(address(pool));
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_without_fee"
        );
        console2.log(
            "Fixture::transfer_20_weth_without_fee::MerkleRoot:",
            stx.commitmentTreeRoot
        );

        _checkEventEmits(stx);
        assertEq(token1.balanceOf(address(pool)), balance1);
    }

    function test_transferWithFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_500_weth_with_weth_fee"
        );

        uint72 feeValue = uint72(stx.feeData);
        address paymaster = address(bytes20(bytes32(stx.feeData)));
        _checkEventEmits(stx);

        vm.prank(paymaster);
        uint256 paymasterFee = pool.getCollectedPaymasterFee(
            asset1.id,
            paymaster
        );
        assertEq(token1.balanceOf(address(pool)), balance1);
        assertEq(paymasterFee, feeValue);
    }

    function test_transferWethWithUsdcFee() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_1000_weth_with_usdc_fee"
        );
        uint24 feeAssetId = uint24(stx.feeData >> 72);
        uint72 feeValue = uint72(stx.feeData);
        address paymaster = address(bytes20(bytes32(stx.feeData)));

        _checkEventEmits(stx);

        vm.prank(paymaster);
        uint256 paymasterFee = pool.getCollectedPaymasterFee(
            feeAssetId,
            paymaster
        );
        assertEq(token1.balanceOf(address(pool)), balance1);
        assertEq(token2.balanceOf(address(pool)), balance2);
        assertEq(paymasterFee, feeValue);
    }

    function test_transferWethWithUsdcFeeWithThreeOutputNotes() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_500_weth_with_usdc_fee"
        );
        uint24 feeAssetId = uint24(stx.feeData >> 72);
        uint72 feeValue = uint72(stx.feeData);
        address paymaster = address(bytes20(bytes32(stx.feeData)));

        _checkEventEmits(stx);

        vm.prank(paymaster);
        uint256 paymasterFee = pool.getCollectedPaymasterFee(
            feeAssetId,
            paymaster
        );
        assertEq(token1.balanceOf(address(pool)), balance1);
        assertEq(token2.balanceOf(address(pool)), balance2);
        assertEq(paymasterFee, feeValue);
    }

    function test_revertOnDoubleSpendTransfer() external {
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_500_weth_without_fee"
        );
        pool.transact(stx);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DoubleSpend.selector,
                stx.nullifiers[0]
            )
        );
        pool.transact(stx);
    }
}
