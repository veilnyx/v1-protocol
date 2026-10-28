// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {StdCheats} from "forge-std/StdCheats.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {Gateway} from "src/core/Gateway.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {MockWToken} from "test/mocks/MockWToken.sol";
import {IWToken} from "src/interfaces/IWToken.sol";

/// Regression test for the paymaster free-sponsorship finding (2026-09 audit).
///
/// `poc_fee_transfer_nopub` is a real proof (production zkeys): a TRANSFER with no public
/// assets whose feeData advertises a 1 WETH fee to the paymaster. The pool ignores feeData
/// when there are no public assets, so the paymaster sponsored the op and was paid nothing.
contract PaymasterFeeBackingTest is PoolTest {
    EntryPoint ep;
    Gateway gw;
    Paymaster pm;
    address constant PM = address(uint160(0xfe01));

    function setUp() public {
        _setUp();
        ep = new EntryPoint();
        gw = new Gateway(ep, IWToken(address(new MockWToken())), pool);
        StdCheats.deployCodeTo("Paymaster.sol:Paymaster", abi.encode(ep, address(gw), address(pool), 1 days), PM);
        pm = Paymaster(payable(PM));
        vm.deal(address(this), 10 ether);
        pm.depositToEntryPoint{value: 10 ether}();
    }

    function test_paymasterRefusesFeelessTransfer() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction("poc_fee_transfer_nopub");
        assertEq(stx.pubAssets.length, 0);
        uint24 feeAssetId = uint24(stx.feeData >> 72);
        uint256 fee = uint72(stx.feeData);

        PackedUserOperation memory op;
        op.sender = address(gw);
        op.callData = abi.encodeCall(Gateway.handleUserOp, (stx));
        op.accountGasLimits = bytes32((uint256(300_000) << 128) | uint256(4_000_000));
        op.preVerificationGas = 100_000;
        op.gasFees = bytes32((uint256(1 gwei) << 128) | uint256(10 gwei));
        op.paymasterAndData = abi.encodePacked(PM, uint128(600_000), uint128(0));
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = op;

        uint256 depBefore = pm.getEntryPointDeposit();
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA33 reverted",
                abi.encodeWithSelector(Paymaster.FeeNotPaidByTransaction.selector, feeAssetId, fee)
            )
        );
        ep.handleOps(ops, payable(address(0xB0B)));
        assertEq(pm.getEntryPointDeposit(), depBefore, "paymaster deposit untouched");
    }
}
