// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {StdCheats} from "forge-std/StdCheats.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

/// Regression tests for the paymaster-fee findings (2026-09 audit).
///
/// The transact circuit has no fee signal: `feeData` is bound to the proof but the value it
/// names is not deducted from any note. Before the fix the pool credited it anyway, so a
/// DEPOSIT (or a zero-value WITHDRAW) could credit an arbitrary fee to an attacker-chosen
/// "paymaster" and drain honest deposits via `withdrawPaymasterFee`.
///
/// The `poc_fee_*` fixtures are real proofs made with the production zkeys.
contract FeeBackingTest is PoolTest {
    address constant ATTACKER = 0x000000000000000000000000000000000000a77A;

    function setUp() public {
        _setUp();
        _makePreDeposit(); // honest liquidity in asset1 (WETH-like) and asset2 (USDC-like)
    }

    /// CRITICAL (fixed): a deposit advertising a 100 WETH fee credited it to the attacker
    /// while pulling nothing from them.
    function test_depositWithFeeRejected() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction("poc_fee_deposit");
        uint24 feeAssetId = uint24(stx.feeData >> 72);
        uint256 fee = uint72(stx.feeData);
        assertEq(fee, 100 ether);

        vm.expectRevert(abi.encodeWithSelector(IPool.UnbackedFee.selector, feeAssetId, fee));
        pool.transact(stx);
        assertEq(pool.getCollectedPaymasterFee(asset1.id, ATTACKER), 0);
    }

    /// CRITICAL (fixed): a zero-value WETH withdraw advertising a fee in USDC credited the
    /// pool's whole USDC balance to the attacker.
    function test_feeInAssetNotWithdrawnRejected() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction("poc_fee_withdraw0");
        uint24 feeAssetId = uint24(stx.feeData >> 72);
        uint256 fee = uint72(stx.feeData);
        assertEq(feeAssetId, asset2.id);

        vm.expectRevert(abi.encodeWithSelector(IPool.UnbackedFee.selector, feeAssetId, fee));
        pool.transact(stx);
        assertEq(pool.getCollectedPaymasterFee(asset2.id, ATTACKER), 0);
    }

    /// A fee larger than the public amount of its asset is rejected (canonical pubAssets and
    /// nullifiers untouched, so this fails before the proof is checked).
    function test_feeLargerThanPublicAmountRejected() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction("withdraw_10_weth_with_weth_fee");
        uint256 withdrawn = uint224(stx.pubAssets[0]);
        uint256 over = withdrawn + 1;
        stx.feeData = (stx.feeData >> 72 << 72) | over;

        vm.expectRevert(abi.encodeWithSelector(IPool.UnbackedFee.selector, asset1.id, over));
        pool.transact(stx);
    }

    /// Honest path: fee paid in the withdrawn asset.
    function test_control_feeInWithdrawnAsset() public {
        ShieldedTransaction memory a = _loadShieldedTransaction("withdraw_10_weth_with_weth_fee");
        pool.transact(a);
        assertEq(pool.getCollectedPaymasterFee(asset1.id, address(bytes20(bytes32(a.feeData)))), uint72(a.feeData));
    }

    /// MEDIUM (fixed): the deployed Paymaster cannot call `withdrawPaymasterFee`, so its
    /// earnings are stuck. The owner can now move them out; nothing else is touchable.
    function test_ownerRecoversStuckPaymasterFees() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction("withdraw_10_weth_with_weth_fee");
        pool.transact(stx);
        address pm = address(bytes20(bytes32(stx.feeData)));
        uint256 fee = uint72(stx.feeData);
        MockERC20 weth = MockERC20(asset1.assetAddress);
        address treasury = makeAddr("treasury");

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        pool.withdrawPaymasterFeeFor(pm, asset1.id, treasury);

        uint256 poolBefore = weth.balanceOf(address(pool));
        pool.withdrawPaymasterFeeFor(pm, asset1.id, treasury);
        assertEq(weth.balanceOf(treasury), fee);
        assertEq(weth.balanceOf(address(pool)), poolBefore - fee);
        assertEq(pool.getCollectedPaymasterFee(asset1.id, pm), 0);

        vm.expectRevert(abi.encodeWithSelector(IPool.NoFeeToClaim.selector, pm, asset1.id));
        pool.withdrawPaymasterFeeFor(pm, asset1.id, treasury);
    }

    /// The new Paymaster can claim its own fees (owner only).
    function test_newPaymasterClaimsPoolFees() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction("withdraw_10_weth_with_weth_fee");
        address pmAddr = address(bytes20(bytes32(stx.feeData)));
        EntryPoint ep = new EntryPoint();
        StdCheats.deployCodeTo(
            "Paymaster.sol:Paymaster",
            abi.encode(ep, makeAddr("gateway"), address(pool), uint256(1 days)),
            pmAddr
        );
        Paymaster pm = Paymaster(payable(pmAddr));
        pool.transact(stx);

        address treasury = makeAddr("treasury");
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        pm.claimPoolFees(asset1.id, treasury);

        pm.claimPoolFees(asset1.id, treasury);
        assertEq(MockERC20(asset1.assetAddress).balanceOf(treasury), uint72(stx.feeData));
    }
}
