// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Pool} from "src/core/Pool.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {ZTransaction, ZTransactionType} from "src/libraries/ZTransaction.sol";

contract PaymasterTest is Test {
    address public mockPool;
    address public entryPoint;
    Paymaster public paymaster;

    uint24 defaultAssetId = 65537;
    uint256 defaultFeeValue = 0.1 ether;

    function setUp() public {
        mockPool = address(uint160(uint256(keccak256("pool"))));
        entryPoint = address(new EntryPoint());
        paymaster = new Paymaster(entryPoint, mockPool);
        paymaster.updateAssetFee(defaultAssetId, defaultFeeValue);
    }

    function test_updateFeeAsset() public {
        uint24 assetId = 65538;
        uint256 feeValue = 0.1 ether;
        paymaster.updateAssetFee(assetId, feeValue);
        assertEq(paymaster.getAssetFee(assetId), feeValue);

        bool isSupported = paymaster.isFeeAssetSupported(assetId);
        assertTrue(isSupported);
    }

    function test_depositEntryPoint() public {
        uint256 value = 1000 ether;
        vm.deal(address(this), value);

        paymaster.deposit{value: value}();

        uint256 deposit = paymaster.getDeposit();
        assertEq(deposit, value);

        address withdrawAddress = address(
            uint160(uint256(keccak256("withdraw")))
        );
        uint256 withdrawValue = 100 ether;
        paymaster.withdrawTo(payable(withdrawAddress), withdrawValue);

        uint256 newDeposit = paymaster.getDeposit();

        assertEq(newDeposit, value - withdrawValue);
        assertEq(withdrawAddress.balance, withdrawValue);
    }

    function test_validatePaymasterUserOp() public {
        ZTransaction memory ztx;
        PackedUserOperation memory userOp;

        ztx.pubAssetIds = new uint24[](1);
        ztx.pubAssetIds[0] = defaultAssetId;
        ztx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes12(uint96(0.1 ether))
                )
            )
        );

        userOp.sender = mockPool;
        userOp.callData = abi.encodeCall(Pool.transact, (ztx));

        vm.startPrank(entryPoint);
        (, uint256 flag) = paymaster.validatePaymasterUserOp(
            userOp,
            bytes32(0),
            0
        );
        vm.stopPrank();

        assertEq(flag, 0);
    }
}
