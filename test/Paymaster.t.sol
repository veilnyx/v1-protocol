// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {Pool} from "src/core/Pool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {console2} from "forge-std/console2.sol";

// import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";

contract PaymasterTest is PoolTest {
    Paymaster public paymaster;

    uint24 feeAssetId;
    uint256 feeValue = 0.001 ether;

    PackedUserOperation userOp;

    modifier createPackedUserOps() {
        ShieldedTransaction memory stx;

        stx.pubAssets = new uint248[](1);
        stx.pubAssets[0] = uint248(
            bytes31(bytes.concat(bytes3(feeAssetId), bytes12(uint96(10 ether))))
        );

        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes12(uint96(0.1 ether))
                )
            )
        );

        userOp.sender = address(pool);
        userOp.callData = abi.encodeCall(Pool.transact, (stx));
        _;
    }

    function setUp() public {
        _setUp();
        feeAssetId = asset1.id;
        entryPoint = address(new EntryPoint());
        paymaster = new Paymaster(entryPoint, address(pool));
        console2.log("paymaster:", address(paymaster));
        paymaster.setAssetFee(feeAssetId, feeValue);
    }

    function test_updateFeeAsset() public {
        uint24 assetId = 65538;
        uint256 newFeeValue = 0.1 ether;
        paymaster.setAssetFee(assetId, newFeeValue);
        assertEq(paymaster.getAssetFee(assetId), newFeeValue);

        bool isSupported = paymaster.isAssetFeeSupported(assetId);
        assertTrue(isSupported);
    }

    function test_depositAndWithdrawEntryPoint() public {
        uint256 value = 1000 ether;
        vm.deal(address(this), value);

            paymaster.depositToEntryPoint{value: value}();

            uint256 deposit = paymaster.getEntryPointDeposit();
            assertEq(deposit, value);

            address withdrawAddress = makeAddr("withdraw");
            uint256 withdrawValue = 100 ether;
            paymaster.withdrawFromEntryPoint(
                payable(withdrawAddress),
                withdrawValue
            );

            uint256 depositBal = paymaster.getEntryPointDeposit();

            assertEq(depositBal, value - withdrawValue);
            assertEq(withdrawAddress.balance, withdrawValue);
    }

    function test_withdrawAsset() public {
        uint256 value = 10 ether;
        vm.deal(address(this), value);
        (bool success, ) = address(paymaster).call{value: value}("");
        assertTrue(success);

        address withdraw = makeAddr("withdraw");
        paymaster.withdrawAsset(address(0), payable(withdraw), value);

        assertEq(withdraw.balance, value);
    }

    ///////////////////////////////////////////
    /// Paymaster UserOp Validation tests /////
    //////////////////////////////////////////
    function test_revertWhenSenderIsNotPool() public createPackedUserOps {
        userOp.sender = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(Paymaster.InvalidSender.selector, address(0))
        );
        vm.startPrank(entryPoint);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
        vm.stopPrank();
    }

    function test_revertWhenPaymasterFeesIsNotEnough() public {
        ShieldedTransaction memory stx;

        stx.pubAssets = new uint248[](1);
        stx.pubAssets[0] = uint248(
            bytes31(bytes.concat(bytes3(feeAssetId), bytes12(uint96(10 ether))))
        );

        uint256 lowFeeValue = feeValue / 2;

        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes12(uint96(lowFeeValue))
                )
            )
        );

        userOp.sender = address(pool);
        userOp.callData = abi.encodeCall(Pool.transact, (stx));

        vm.prank(entryPoint);
        vm.expectRevert(
            abi.encodeWithSelector(
                Paymaster.InsufficientFee.selector,
                lowFeeValue,
                feeValue
            )
        );
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
    }

    function test_validatePaymasterUserOp() public createPackedUserOps {
        vm.startPrank(entryPoint);
        (, uint256 flag) = paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            0
        );
        vm.stopPrank();

        assertEq(flag, 0);
    }

    function test_paymasterFeeBalUpdateInPool() external {
        _makePreDeposit();

        uint256 value = 1000 ether;
        vm.deal(address(this), value);
        paymaster.depositToEntryPoint{value: value}();

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        pool.transact(stx);

        uint256 assetFeeByPaymaster = paymaster.getAssetFee(feeAssetId);
        vm.prank(address(paymaster));
        assertEq(
            pool.getCollectedPaymasterFee(feeAssetId, address(paymaster)),
            assetFeeByPaymaster
        );
    }

    function test_paymasterFeeClaim() external {
        _makePreDeposit();

        uint256 value = 1000 ether;
        vm.deal(address(this), value);
        paymaster.depositToEntryPoint{value: value}();

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_10_weth_with_weth_fee"
        );
        pool.transact(stx);

        vm.startPrank(address(paymaster));
        pool.withdrawPaymasterFee(feeAssetId, address(paymaster));

        assertEq(
            pool.getCollectedPaymasterFee(feeAssetId, address(paymaster)),
            0
        );
        assertEq(token1.balanceOf(address(paymaster)), feeValue);
    }
}
