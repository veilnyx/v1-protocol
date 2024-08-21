// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Gateway} from "src/core/Gateway.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {MockWToken} from "test/mocks/MockWToken.sol";

contract MockPool {
    function transact(ShieldedTransaction calldata) external {
        // Simulate gas usage
        for (uint256 i = 0; i < 10; i++) {
            new MockWToken();
        }
    }
}

contract GatewayTest is Test {
    MockPool public pool;
    EntryPoint public entryPoint;
    Paymaster paymaster;

    Gateway gateway;
    address wToken;
    address payable beneficiary = payable(address(0x123));

    uint128 baseFee = 25 gwei;
    uint24 assetId = 65537;
    uint256 paymasterFeeValue = 0.1 ether;

    function setUp() public {
        entryPoint = new EntryPoint();
        pool = new MockPool();
        wToken = address(new MockWToken());
        gateway = new Gateway(
            address(entryPoint),
            address(wToken),
            address(pool)
        );
        paymaster = new Paymaster(address(entryPoint), address(gateway));

        // Deposit to entry point
        vm.deal(address(this), 100 ether);
        paymaster.depositToEntryPoint{value: 100 ether}();
        paymaster.setAssetFee(assetId, paymasterFeeValue);
    }

    function test_handleWrapAndDeposit() public {
        vm.deal(address(this), 100 ether);
        ShieldedTransaction memory stx;
        stx.txType = ShieldedTransactionType.DEPOSIT;
        gateway.handleWrapAndDeposit{value: 100 ether}(stx);
    }

    function test_handleUserOp() public {
        ShieldedTransaction memory stx;

        uint24[] memory pubAssetIds = new uint24[](1);
        uint224[] memory pubAssetValues = new uint224[](1);
        uint248[] memory pubAssets = new uint248[](1);
        pubAssetIds[0] = assetId;
        pubAssetValues[0] = 1 ether;
        pubAssets[0] = uint248(
            bytes31(
                bytes.concat(bytes3(pubAssetIds[0]), bytes28(pubAssetValues[0]))
            )
        );

        stx.pubAssets = pubAssets;
        stx.feeData = uint256(
            bytes32(
                bytes.concat(
                    bytes20(address(paymaster)),
                    bytes12(uint96(paymasterFeeValue))
                )
            )
        );

        uint128 callGasLimit = uint128(2_000_000);
        uint128 verificationGasLimit = uint128(50_000);
        uint256 preVerificationGas = uint256(10_000);
        uint128 maxFeePerGas = baseFee;
        uint128 maxPriorityFeePerGas = baseFee;
        uint128 paymasterVerificationGasLimit = uint128(50_000);
        uint128 paymasterPostOpGasLimit = uint128(10_000);

        PackedUserOperation memory userOp;
        userOp.sender = address(gateway);
        userOp.callData = abi.encodeCall(Gateway.handleUserOp, stx);
        userOp.accountGasLimits = bytes32(
            bytes.concat(bytes16(verificationGasLimit), bytes16(callGasLimit))
        );
        userOp.preVerificationGas = preVerificationGas;
        userOp.gasFees = bytes32(
            bytes.concat(bytes16(maxPriorityFeePerGas), bytes16(maxFeePerGas))
        );
        userOp.paymasterAndData = bytes.concat(
            bytes20(address(paymaster)),
            bytes16(paymasterVerificationGasLimit),
            bytes16(paymasterPostOpGasLimit)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        entryPoint.handleOps(userOps, beneficiary);
    }
}
