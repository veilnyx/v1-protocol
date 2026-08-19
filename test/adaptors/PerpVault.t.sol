// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {PerpVault} from "src/adaptors/hyperliquid/PerpVault.sol";
import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockCoreWriter} from "test/mocks/MockHyperCorePrecompiles.sol";
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

        // A recording CoreWriter rather than a bare STOP, so the orders the vault
        // would place can be asserted on rather than merely not reverting.
        MockCoreWriter cw = new MockCoreWriter();
        vm.etch(HyperCore.CORE_WRITER, address(cw).code);

        _setCore({equityCoreUnits: 0, szi: 0, markPx: 1_000_000});
        vault.setEntryFeeBps(0); // isolated from fee effects unless a test opts in

        // Start past the rebalance cooldown so the first keeper run is allowed.
        vm.warp(block.timestamp + 1 days);

        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
    }

    /// @dev equityCoreUnits is perp accountValue, which is 1e6 — the SAME scale as
    ///      6dp USDC, not 100x it. The mock previously used 8dp, matching a wrong
    ///      assumption in the contract, so the suites agreed with each other and
    ///      both were wrong. Real testnet reads exposed it.
    ///      markPx follows the perp convention of `6 - szDecimals` decimals, so
    ///      $100,000 on a szDecimals=5 market is 1_000_000, not 100_000e6.
    uint256 internal coreSpot8; // Core spot balance, weiDecimals (8)

    function _setCore(uint256 equityCoreUnits, int64 szi, uint64 markPx) internal {
        vm.mockCall(
            HyperCore.MARGIN_SUMMARY,
            abi.encode(uint32(0), address(vault)),
            abi.encode(HyperCore.MarginSummary(int64(uint64(equityCoreUnits)), 0, 0, int64(0)))
        );
        vm.mockCall(
            HyperCore.POSITION, abi.encode(address(vault), PERP), abi.encode(HyperCore.Position(szi, 0, 0, 10, false))
        );
        vm.mockCall(HyperCore.MARK_PX, abi.encode(PERP), abi.encode(markPx));
        vm.mockCall(
            HyperCore.SPOT_BALANCE,
            abi.encode(address(vault), TOKEN_INDEX),
            abi.encode(HyperCore.SpotBalance(uint64(coreSpot8), 0, 0))
        );
        // Mirrors BTC on chain 998: szDecimals 5, maxLeverage 40.
        vm.mockCall(
            HyperCore.PERP_ASSET_INFO,
            abi.encode(PERP),
            abi.encode(HyperCore.PerpAssetInfo("BTC", uint32(54), uint8(5), uint8(40), false))
        );
        // A tight two-sided book around the mark, so marketable pricing is exercised.
        vm.mockCall(
            HyperCore.BBO,
            abi.encode(PERP),
            abi.encode(HyperCore.Bbo({bid: markPx - 50, ask: markPx + 50}))
        );

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
        _setCore({equityCoreUnits: 12_000e6, szi: 0, markPx: 1_000_000});

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
        _setCore({equityCoreUnits: 12_000e6, szi: 0, markPx: 1_000_000});
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
        _setCore({equityCoreUnits: 9_000e6, szi: 0, markPx: 1_000_000});

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
        _setCore({equityCoreUnits: 3_694e6, szi: 0, markPx: 947_000});
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
        _setCore({equityCoreUnits: 50_000e6, szi: 0, markPx: 1_000_000});

        assertEq(vault.balanceOf(alice), shares, "balance must not move with NAV");
        assertEq(vault.totalSupply(), shares);
    }

    // -------------------------------------------------------------- orders

    /// @dev Guards the unit conversion between notional and HyperCore order size.
    ///      Perp prices carry `6 - szDecimals` decimals and sizes carry
    ///      `szDecimals`, so the two cancel to a fixed 1e6 factor. An earlier
    ///      version reused CORE_TO_EVM_SCALE here, which governs the USDC bridge
    ///      and nothing else, and understated every order by 1e6 — the vault would
    ///      have opened a position a millionth of the intended size. Nothing else
    ///      in this suite looks at the emitted order, so without this it regresses
    ///      silently.
    function test_rebalanceOrderSizeUsesPerpDecimals() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        // 10,000 equity at 2x -> 20,000 notional. At $100,000/BTC that is 0.2 BTC,
        // which on a szDecimals=5 market is 20_000 raw units.
        vault.rebalance();

        MockCoreWriter cw = MockCoreWriter(HyperCore.CORE_WRITER);
        assertEq(cw.actionCount(), 1, "rebalance must emit exactly one order");

        bytes memory raw = cw.actions(0);
        assertEq(uint8(raw[0]), 1, "encoding version");
        assertEq(uint8(raw[3]), uint8(HyperCore.ACTION_LIMIT_ORDER), "action id");

        bytes memory payload = new bytes(raw.length - 4);
        for (uint256 i = 0; i < payload.length; i++) {
            payload[i] = raw[i + 4];
        }
        (uint32 perp, bool isBuy,, uint64 sz,,,) =
            abi.decode(payload, (uint32, bool, uint64, uint64, bool, uint8, uint128));

        assertEq(perp, PERP);
        assertTrue(isBuy, "long vault opening should buy");
        // CoreWriter writes are a uniform 1e8, NOT the per-asset szDecimals the
        // precompiles report. 0.2 BTC on the wire is 0.2 * 1e8.
        assertEq(sz, 20_000_000, "0.2 BTC as 1e8 wire units");
    }

    // --------------------------------------------------------------- bridge

    /// @dev The bridge is not atomic. Between the ERC20 leaving and Core crediting
    ///      it, the amount is invisible to idleAssets() (balanceOf already fell)
    ///      and to coreEquity() (not credited yet). Untracked, NAV collapses for
    ///      the duration and recovers — a free round trip for anyone watching.
    function test_navHoldsSteadyAcrossTheBridgeWindow() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        uint256 navBefore = vault.pricePerShare();
        assertEq(vault.totalAssets(), 10_000e6);

        // Bridge the whole idle balance. The ERC20 leaves immediately.
        vault.postMargin(10_000e6);

        assertEq(vault.idleAssets(), 0, "ERC20 has left");
        assertEq(vault.coreEquity(), 0, "Core has not credited yet");
        assertEq(vault.bridgeInFlight(), 10_000e6, "tracked as in flight");
        assertEq(vault.totalAssets(), 10_000e6, "NAV must not dip mid-bridge");
        assertEq(vault.pricePerShare(), navBefore, "price per share unchanged");
    }

    /// @dev Core may credit in parts, so settlement measures the delta rather than
    ///      assuming the whole transfer arrived.
    function test_bridgeSettlesPartialCredits() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);
        vault.postMargin(10_000e6);

        // Only 6,000 lands (spot is weiDecimals=8, so 100x the 6dp asset value).
        coreSpot8 = 6_000e6 * 100;
        _setCore({equityCoreUnits: 0, szi: 0, markPx: 1_000_000});

        // Whole before settlement is even called: the credit shows up in coreSpot
        // and pendingBridge falls by the same amount.
        assertEq(vault.totalAssets(), 10_000e6, "NAV whole before settlement");

        uint256 credited = vault.settleBridge();
        assertEq(credited, 6_000e6, "only what actually landed");
        assertEq(vault.bridgeInFlight(), 4_000e6, "remainder still in flight");

        // Settlement moved the credited part spot -> perp.
        coreSpot8 = 0;
        _setCore({equityCoreUnits: 6_000e6, szi: 0, markPx: 1_000_000});
        assertEq(vault.totalAssets(), 10_000e6, "NAV still whole after settlement");
    }

    // ------------------------------------------------------------- distress

    /// @dev The worst failure mode: a liquidated vault quietly taking new money.
    ///      Deposits must latch shut on the deposit that discovers the distress,
    ///      not after an operator notices.
    function test_depositLatchesShutWhenDistressed() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);
        _moveToCore(10_000e6);

        // Live position whose equity has fallen to the maintenance requirement.
        // 0.2 BTC at $100,000 = 20,000 notional; maintenance at maxLeverage 40 is
        // 20,000/80 = 250. Put equity just under that.
        _setCore({equityCoreUnits: 200e6, szi: 20_000, markPx: 1_000_000});

        assertTrue(vault.isDistressed(), "equity at/below maintenance is distress");
        assertFalse(vault.depositsFrozen(), "not yet observed");

        // Refused on the live condition, with no prior flagging required.
        vm.prank(bob);
        vm.expectRevert(PerpVault.VaultDistressed.selector);
        vault.deposit(1_000e6, bob);

        // The latch is a separate, non-reverting call: state set inside a reverting
        // deposit would be rolled back with it.
        vault.flagDistress();
        assertTrue(vault.depositsFrozen(), "latch persists once flagged");
    }

    /// @dev Anyone may flag distress; only the owner may clear it. Halt-then-resume.
    function test_flagDistressIsPermissionlessButClearingIsNot() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);
        _moveToCore(10_000e6);
        _setCore({equityCoreUnits: 200e6, szi: 20_000, markPx: 1_000_000});

        vm.prank(address(0xBEEF));
        assertTrue(vault.flagDistress(), "anyone can halt a distressed vault");
        assertTrue(vault.depositsFrozen());

        vm.prank(address(0xBEEF));
        vm.expectRevert();
        vault.setDepositsFrozen(false);

        vault.setDepositsFrozen(false); // owner
        assertFalse(vault.depositsFrozen());
    }

    /// @dev Redemptions stay open while distressed: halt entry, never trap holders.
    function test_redeemStillWorksWhileDistressed() public {
        vm.prank(alice);
        uint256 shares = vault.deposit(10_000e6, alice);
        _setCore({equityCoreUnits: 0, szi: 20_000, markPx: 1_000_000});

        assertTrue(vault.isDistressed());
        vm.prank(alice);
        vault.redeem(shares / 2, alice); // must not revert
    }

    /// @dev Back-to-back rebalances inside the CoreWriter delay would place two
    ///      orders closing the same gap, silently doubling exposure.
    function test_rebalanceRejectsSecondCallInsideCooldown() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        vault.rebalance();
        vm.expectRevert(
            abi.encodeWithSelector(
                PerpVault.RebalanceTooSoon.selector, block.timestamp + vault.rebalanceCooldown()
            )
        );
        vault.rebalance();

        vm.warp(block.timestamp + vault.rebalanceCooldown() + 1);
        vault.rebalance(); // allowed once the window passes
    }

    /// @dev Hyperliquid rejects perp prices with more than 5 significant figures,
    ///      and the rejection is silent — no order, no fill, no error. A live
    ///      testnet rebalance sent 647169 ($64,716.9, six figures) and simply
    ///      vanished. Buys must round up so the limit stays marketable.
    function test_orderPriceIsRoundedToFiveSigFigs() public {
        vm.prank(alice);
        vault.deposit(10_000e6, alice);

        // Book placed so the slippage-bounded price lands on six figures.
        vm.mockCall(
            HyperCore.BBO, abi.encode(PERP), abi.encode(HyperCore.Bbo({bid: 643_800, ask: 643_840}))
        );
        vault.rebalance();

        MockCoreWriter cw = MockCoreWriter(HyperCore.CORE_WRITER);
        bytes memory raw = cw.actions(cw.actionCount() - 1);
        bytes memory payload = new bytes(raw.length - 4);
        for (uint256 i = 0; i < payload.length; i++) payload[i] = raw[i + 4];
        (,, uint64 limitPx,,,,) =
            abi.decode(payload, (uint32, bool, uint64, uint64, bool, uint8, uint128));

        // Significant figures, not digits: 647060 has six digits but five
        // significant figures, the trailing zero being a placeholder.
        uint256 t = limitPx;
        while (t % 10 == 0 && t > 0) {
            t /= 10;
        }
        uint256 figs;
        while (t > 0) {
            figs++;
            t /= 10;
        }
        assertLe(figs, 5, "perp prices may carry at most 5 significant figures");
        // Wire scale: read px 643_840 (=$64,384.0) becomes $ * 1e8.
        assertGe(limitPx, uint64(643_840) * 1e7, "a buy must round UP, staying above the ask");
    }

    // ------------------------------------------------------------ hypercore

    function test_systemAddressEncoding() public pure {
        // Documented example: token index 1385 -> 0x20..0569
        assertEq(HyperCore.systemAddress(1385), 0x2000000000000000000000000000000000000569);
        assertEq(HyperCore.systemAddress(0), 0x2000000000000000000000000000000000000000);
    }
}
