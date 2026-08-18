// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpVault} from "src/adaptors/hyperliquid/PerpVault.sol";
import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Unit tests for PerpVault share accounting.
/// @dev HyperCore is mocked: CoreWriter is etched with a bare STOP so actions
///      succeed and go nowhere, and the read precompiles are driven by vm.mockCall.
///      This proves the ECONOMICS only. Bridging, order execution and real fills
///      are unprovable off HyperEVM and belong to testnet validation.
contract PerpVaultTest is Test {
    uint8 constant USDC_DECIMALS = 6;
    uint32 constant PERP = 3;
    uint64 constant TOKEN_INDEX = 0;

    MockERC20 usdc;
    PerpVault vault;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        usdc = new MockERC20(owner, USDC_DECIMALS);
        vault = new PerpVault(IERC20(address(usdc)), TOKEN_INDEX, PERP, true, 20_000, "BTC Long 2x", "vBTC2L", owner);

        // CoreWriter: single STOP opcode, so every action call succeeds silently.
        vm.etch(HyperCore.CORE_WRITER, hex"00");

        _setCore({equityCoreUnits: 0, szi: 0, markPx: 100_000e6});
        vault.setEntryFeeBps(0); // isolated from fee effects unless a test opts in

        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
    }

    /// @dev equityCoreUnits is in Core's 8-decimal USD, i.e. 100x the ERC20 value.
    function _setCore(uint256 equityCoreUnits, int64 szi, uint64 markPx) internal {
        vm.mockCall(
            HyperCore.MARGIN_SUMMARY,
            abi.encode(uint32(0), address(vault)),
            abi.encode(HyperCore.MarginSummary(int64(uint64(equityCoreUnits)), 0, 0, 0))
        );
        vm.mockCall(
            HyperCore.POSITION, abi.encode(address(vault), PERP), abi.encode(HyperCore.Position(szi, 0, 0, 10, false))
        );
        vm.mockCall(HyperCore.MARK_PX, abi.encode(PERP), abi.encode(markPx));
    }

    /// @dev Stand-in for the bridge: the ERC20 leaves the vault on the EVM side.
    ///      The matching Core credit is applied separately via _setCore.
    function _moveToCore(uint256 amount) internal {
        vm.prank(address(vault));
        usdc.transfer(address(0xdead), amount);
    }

    // ------------------------------------------------------------------ NAV

    function test_bootstrapNavIsOne() public view {
        assertEq(vault.pricePerShare(), 1e6, "empty vault must bootstrap at NAV 1.0");
    }

    function test_navCountsIdleAssetsNotJustCore() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        // Everything is still idle on the EVM side; Core equity is zero.
        assertEq(vault.coreEquity(), 0);
        assertEq(vault.idleAssets(), 10_000e6);
        assertEq(vault.totalAssets(), 10_000e6, "NAV must count both sides of the bridge");
        assertEq(vault.pricePerShare(), 1e6);
    }

    function test_navRisesWithCoreEquity() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        // Simulate the deposit having reached Core and the position gaining 20%.
        _moveToCore(10_000e6);
        _setCore({equityCoreUnits: 12_000e8, szi: 0, markPx: 100_000e6});

        assertEq(vault.totalAssets(), 12_000e6);
        // Virtual-offset conversion rounds DOWN, in favour of existing holders.
        assertApproxEqAbs(vault.pricePerShare(), 1.2e6, 1, "NAV = equity / shares");
    }

    // -------------------------------------------------------------- deposit

    /// @dev The property from the plan: a later depositor buys none of an earlier
    ///      depositor's gain, because their shares are struck at the higher NAV.
    function test_secondDepositorDoesNotBuyFirstDepositorsGain() public {
        vm.prank(alice);
        uint256 aliceShares = vault.deposit(10_000e6, alice);
        assertEq(aliceShares, 10_000e18);

        // Vault is now worth 12,000 on 10,000 shares -> NAV 1.2
        _moveToCore(10_000e6);
        _setCore({equityCoreUnits: 12_000e8, szi: 0, markPx: 100_000e6});
        assertApproxEqAbs(vault.pricePerShare(), 1.2e6, 1);

        vm.prank(bob);
        uint256 bobShares = vault.deposit(12_000e6, bob);

        // ~1.7e-11 relative drift from the virtual-share offset; inherent to the
        // technique and economically nil, but not exactly zero.
        assertApproxEqRel(bobShares, 10_000e18, 1e12, "12,000 at NAV 1.2 must buy 10,000 shares");
        assertApproxEqAbs(vault.convertToAssets(aliceShares), 12_000e6, 2, "Alice keeps her gain");
        assertApproxEqAbs(vault.convertToAssets(bobShares), 12_000e6, 2, "Bob starts at what he paid");
    }

    /// @dev Reversing pull-then-price would let a depositor buy their own money.
    function test_sharesStruckAtPreDepositNav() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        uint256 navBefore = vault.pricePerShare();
        vm.prank(bob);
        uint256 bobShares = vault.deposit(10_000e6, bob);

        assertEq(navBefore, 1e6);
        assertEq(bobShares, 10_000e18, "priced at PRE-deposit NAV, not post");
        assertEq(vault.pricePerShare(), 1e6, "NAV unchanged by a deposit at NAV");
    }

    function test_entryFeeAccruesToExistingHolders() public {
        vault.setEntryFeeBps(100); // 1%

        vm.prank(alice);
        uint256 aliceShares = vault.deposit(10_000e6, alice);

        vm.prank(bob);
        vault.deposit(10_000e6, bob);

        // Bob is credited 9,900 but the full 10,000 entered the vault, so the
        // 100 surplus lifts NAV for everyone already in.
        assertGt(vault.convertToAssets(aliceShares), 10_000e6, "fee surplus accrues to holders");
    }

    function test_depositRevertsWhenFrozen() public {
        vault.setDepositsFrozen(true);
        vm.prank(alice);
        vm.expectRevert(PerpVault.DepositsAreFrozen.selector);
        vault.deposit(1_000e6, alice);
    }

    // --------------------------------------------------------------- redeem

    function test_redeemPaysNavFromBuffer() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10_000e6, alice);

        uint256 before = usdc.balanceOf(alice);
        vm.prank(alice);
        uint256 assets = vault.redeem(shares / 2, alice);

        assertApproxEqAbs(assets, 5_000e6, 1);
        assertApproxEqAbs(usdc.balanceOf(alice) - before, 5_000e6, 1);
        assertEq(vault.balanceOf(alice), shares / 2);
    }

    /// @dev Stage 1 is buffer-only. The CLAIM queue for the overflow case is not
    ///      built yet, so this must fail loudly rather than appear to succeed.
    function test_redeemRevertsWhenBufferInsufficient() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10_000e6, alice);

        // Move most of it to Core, leaving a thin buffer.
        _moveToCore(9_000e6);
        _setCore({equityCoreUnits: 9_000e8, szi: 0, markPx: 100_000e6});

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PerpVault.InsufficientIdleLiquidity.selector, 10_000e6, 1_000e6));
        vault.redeem(shares, alice);
    }

    /// @dev Redemptions must stay open when deposits are frozen, per the
    ///      liquidation handling rule: halt entry, never trap holders.
    function test_redeemStillWorksWhileDepositsFrozen() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10_000e6, alice);
        vault.setDepositsFrozen(true);

        vm.prank(alice);
        uint256 assets = vault.redeem(shares, alice);
        assertApproxEqAbs(assets, 10_000e6, 1);
    }

    // ---------------------------------------------------- liquidation shape

    /// @dev After a liquidation the vault keeps operating and a fresh deposit
    ///      simply prices at the depressed NAV. No migration, no rebase.
    function test_restartsCorrectlyAfterLiquidation() public {
        vm.prank(alice);
        uint256 aliceShares = vault.deposit(10_000e6, alice);
        _moveToCore(10_000e6);

        // Liquidated: equity collapses to the residual, shares untouched.
        _setCore({equityCoreUnits: 3_694e8, szi: 0, markPx: 94_700e6});
        assertApproxEqRel(vault.pricePerShare(), 0.3694e6, 1e15, "NAV reprices, notes survive");

        vm.prank(bob);
        uint256 bobShares = vault.deposit(5_000e6, bob);

        // Bob buys in at the post-liquidation NAV and gets proportionally more shares.
        assertApproxEqRel(bobShares, 13_534e18, 1e15);
        assertApproxEqRel(vault.convertToAssets(aliceShares), 3_694e6, 1e15, "Alice not rescued");
        assertApproxEqRel(vault.convertToAssets(bobShares), 5_000e6, 1e15, "Bob buys no loss");
    }

    // --------------------------------------------------------------- shares

    function test_sharesAreNonRebasing() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10_000e6, alice);

        _moveToCore(10_000e6);
        _setCore({equityCoreUnits: 50_000e8, szi: 0, markPx: 100_000e6});

        assertEq(vault.balanceOf(alice), shares, "balance must not move with NAV");
        assertEq(vault.totalSupply(), shares);
    }

    // ------------------------------------------------------------ hypercore

    function test_systemAddressEncoding() public pure {
        // Documented example: token index 1385 -> 0x20..0569
        assertEq(HyperCore.systemAddress(1385), 0x2000000000000000000000000000000000000569);
        assertEq(HyperCore.systemAddress(0), 0x2000000000000000000000000000000000000000);
    }
}
