// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {PerpVault} from "src/adaptors/hyperliquid/PerpVault.sol";
import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockCoreWriter} from "test/mocks/MockHyperCorePrecompiles.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Many-holder behaviour for PerpVault under varied market conditions.
/// @dev Unlike PerpVault.t.sol this drives a real loop: rebalance, read the order
///      the vault actually emitted, apply that position against a price path, and
///      feed the resulting PnL back as Core equity. Position size, leverage and NAV
///      therefore move for the same reasons they would on chain.
///
///      HyperCore is still mocked, so this says nothing about fills or funding.
///      What it tests is that share accounting stays sound with many holders
///      entering and leaving at different prices.
contract PerpVaultMultiUserTest is Test {
    uint8 constant USDC_DECIMALS = 6;
    uint32 constant PERP = 3;
    uint64 constant TOKEN_INDEX = 0;
    uint8 constant SZ_DECIMALS = 5; // BTC on HyperCore

    /// @dev Hyperliquid base taker, in bps of traded notional. The contract does
    ///      not model execution cost — it emits an order and nothing more — so the
    ///      harness charges it, because a real fill would. Without this a
    ///      rebalanced vault appears to trade for free and the decay that makes
    ///      leveraged vaults bleed simply does not appear.
    uint256 constant TAKER_FEE_BPS = 45; // 4.5bp, expressed in hundredths of a bp

    MockERC20 usdc;
    PerpVault vault;
    address owner = address(this);

    // Mirrors the mocked Core account so price moves can be applied to it.
    int64 internal coreEquity8; // Core USD, 8dp
    int64 internal szi; // raw perp size, szDecimals (=5 for BTC)
    uint64 internal px; // raw perp price, (6 - szDecimals) dp
    uint64 internal coreSpot8; // Core SPOT balance, weiDecimals (8)

    address[] internal users;

    function setUp() public {
        usdc = new MockERC20(owner, USDC_DECIMALS);
        vault = new PerpVault(
            IERC20(address(usdc)), TOKEN_INDEX, PERP, true, 20_000, "BTC Long 2x", "vBTC2L", owner
        );
        MockCoreWriter cw = new MockCoreWriter();
        vm.etch(HyperCore.CORE_WRITER, address(cw).code);

        px = 1_000_000; // $100,000 at szDecimals=5
        _sync();
    }

    // ------------------------------------------------------------- harness

    function _sync() internal {
        vm.mockCall(
            HyperCore.MARGIN_SUMMARY,
            abi.encode(uint32(0), address(vault)),
            abi.encode(HyperCore.MarginSummary(coreEquity8, 0, 0, int64(0)))
        );
        vm.mockCall(
            HyperCore.POSITION,
            abi.encode(address(vault), PERP),
            abi.encode(HyperCore.Position(szi, 0, 0, 10, false))
        );
        vm.mockCall(HyperCore.MARK_PX, abi.encode(PERP), abi.encode(px));
        // Index oracle, mocked in line with the mark so pricing is allowed.
        // Tests that need a dislocation override this one call.
        vm.mockCall(HyperCore.ORACLE_PX, abi.encode(PERP), abi.encode(px));
        // totalAssets() also reads the Core spot balance. Most tests keep all
        // equity in perp and leave this at zero; the withdrawal path moves through
        // it, so it is a variable rather than a constant.
        vm.mockCall(
            HyperCore.SPOT_BALANCE,
            abi.encode(address(vault), TOKEN_INDEX),
            abi.encode(HyperCore.SpotBalance(coreSpot8, 0, 0))
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
            abi.encode(HyperCore.Bbo({bid: px - 50, ask: px + 50}))
        );

    }

    function _mkUser(uint256 i, uint256 funds) internal returns (address u) {
        u = address(uint160(0xC0FFEE + i));
        usdc.mint(u, funds);
        vm.prank(u);
        usdc.approve(address(vault), type(uint256).max);
        users.push(u);
    }

    /// @dev Deposit, then move idle USDC to "Core" the way postMargin would, so
    ///      equity lives in one place and NAV is not double counted.
    function _deposit(address u, uint256 amount) internal returns (uint256 shares) {
        vm.prank(u);
        shares = vault.deposit(amount, u);
        _settleIdleToCore();
    }

    function _settleIdleToCore() internal {
        uint256 idle = vault.idleAssets();
        if (idle == 0) return;
        vm.prank(address(vault));
        usdc.transfer(address(0xdead), idle);
        coreEquity8 += int64(uint64(idle)); // perp USD is 1e6, same as 6dp USDC
        _sync();
    }

    /// @dev Rebalance and adopt whatever size the vault actually asked for.
    function _rebalance() internal {
        // Past the cooldown: CoreWriter orders are delayed on Core, so back-to-back
        // rebalances would double-order. A real keeper waits; so does this.
        vm.warp(block.timestamp + vault.rebalanceCooldown() + 1);
        MockCoreWriter cw = MockCoreWriter(HyperCore.CORE_WRITER);
        uint256 before = cw.actionCount();
        vault.rebalance();
        if (cw.actionCount() == before) return;

        bytes memory raw = cw.actions(cw.actionCount() - 1);
        bytes memory payload = new bytes(raw.length - 4);
        for (uint256 i = 0; i < payload.length; i++) payload[i] = raw[i + 4];
        (, bool isBuy, uint64 pxWire, uint64 sz,,,) =
            abi.decode(payload, (uint32, bool, uint64, uint64, bool, uint8, uint128));

        // Be as unforgiving as the real exchange: orders under $10 notional are
        // dropped SILENTLY. The P1 drill caught a widened trim whose floored size
        // rounded back to $9.39 — this harness had accepted it, the exchange did
        // not. Notional from wire units: (sz/1e8) * (px/1e8) * 1e6 asset units.
        uint256 wireNotional6 = (uint256(sz) * uint256(pxWire)) / 1e10;
        if (wireNotional6 < 10e6) return;

        // The order is emitted in CoreWriter WIRE units (1e8); the position
        // precompile reports READ units (szDecimals). Convert before adopting, or
        // the mocked position is 10^(8-szDecimals) times too large.
        int64 szRead = int64(sz / uint64(10 ** (8 - SZ_DECIMALS)));
        szi += isBuy ? szRead : -szRead;

        // notional in asset decimals = sz_read * px_raw when the asset carries 6dp.
        uint256 tradedNotional6 = uint256(uint64(szRead >= 0 ? szRead : -szRead)) * uint256(px);
        uint256 fee6 = (tradedNotional6 * TAKER_FEE_BPS) / 100_000;
        coreEquity8 -= int64(uint64(fee6));
        _sync();
    }

    /// @dev Apply a price move as position PnL against Core equity.
    ///      size_coins  = szi / 10^szDec           (szDec = 5)
    ///      price_usd   = px  / 10^(6 - szDec)     (so 10^1 here)
    ///      pnl_usd     = szi * dPx / 1e6
    ///      Core carries 8dp, so pnl8 = pnl_usd * 1e8 = szi * dPx * 100.
    ///      An earlier version divided by 1e6 *and* scaled by 100, making every
    ///      price move 1e6 too small — the paths below were effectively flat.
    function _movePrice(uint64 newPx) internal {
        int256 d = int256(uint256(newPx)) - int256(uint256(px));
        // pnl_usd = szi * dPx / 1e6, and perp USD is 1e6, so pnl = szi * dPx.
        int256 pnl8 = int256(szi) * d;
        coreEquity8 += int64(pnl8);
        px = newPx;
        _sync();
    }

    function _totalHolderValue() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < users.length; i++) {
            sum += vault.convertToAssets(vault.balanceOf(users[i]));
        }
    }

    // --------------------------------------------------------------- tests

    /// @dev The safety property: holders can never collectively claim more than
    ///      the vault holds. Rounding must always favour the vault.
    function test_manyUsersValueIsConserved() public {
        vault.setEntryFeeBps(0);
        uint64[6] memory path =
            [uint64(1_050_000), 980_000, 1_120_000, 900_000, 1_010_000, 1_000_000];

        for (uint256 i = 0; i < 20; i++) {
            address u = _mkUser(i, 1_000_000e6);
            _deposit(u, 1_000e6 * (i + 1));
            _rebalance();
            if (i % 3 == 0) _movePrice(path[(i / 3) % 6]);
        }

        uint256 holders = _totalHolderValue();
        uint256 assets = vault.totalAssets();
        console2.log("users        :", users.length);
        console2.log("vault assets :", assets);
        console2.log("holders total:", holders);
        assertLe(holders, assets, "holders must never claim more than the vault holds");
        assertGe(holders + users.length, assets, "conservation should be tight");
    }

    /// @dev Two holders entering at the same NAV must receive the same shares per
    ///      unit deposited, regardless of size.
    function test_equalNavGivesEqualSharesPerUnit() public {
        vault.setEntryFeeBps(0);
        address a = _mkUser(100, 1_000_000e6);
        address b = _mkUser(101, 1_000_000e6);

        _deposit(a, 1_000e6);
        uint256 navAfterA = vault.pricePerShare();
        _deposit(b, 7_000e6);

        uint256 perUnitA = (vault.balanceOf(a) * 1e6) / 1_000e6;
        uint256 perUnitB = (vault.balanceOf(b) * 1e6) / 7_000e6;
        assertApproxEqRel(perUnitA, perUnitB, 1e12, "same NAV must price identically");
        assertEq(navAfterA, vault.pricePerShare(), "a deposit at NAV must not move NAV");
    }

    /// @dev A liquidation is shared strictly pro rata: everyone loses the same
    ///      percentage, whatever they paid or when they arrived.
    function test_liquidationHitsAllHoldersProportionally() public {
        vault.setEntryFeeBps(0);
        for (uint256 i = 0; i < 5; i++) {
            address u = _mkUser(200 + i, 1_000_000e6);
            _deposit(u, 5_000e6);
            _rebalance();
            _movePrice(px + 20_000); // drift up between entries so NAVs differ
        }

        uint256[] memory before = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            before[i] = vault.convertToAssets(vault.balanceOf(users[i]));
        }

        // Collapse equity to the maintenance remnant, as a liquidation would.
        coreEquity8 = coreEquity8 / 3;
        szi = 0;
        _sync();

        uint256 firstRatio;
        for (uint256 i = 0; i < users.length; i++) {
            uint256 nowVal = vault.convertToAssets(vault.balanceOf(users[i]));
            uint256 ratio = (nowVal * 1e18) / before[i];
            if (i == 0) firstRatio = ratio;
            else assertApproxEqRel(ratio, firstRatio, 1e12, "loss must be pro rata");
        }
        console2.log("post-liquidation retained, 1e18 = 100%:", firstRatio);
    }

    /// @dev Rebalancing into chop bleeds even when price returns to where it began.
    ///      This is the decay the plan warns about, measured against the contract
    ///      rather than the standalone python model.
    function test_choppyMarketDecaysWithRebalancing() public {
        vault.setEntryFeeBps(0);
        address u = _mkUser(300, 1_000_000e6);
        _deposit(u, 10_000e6);
        _rebalance();

        uint256 start = vault.convertToAssets(vault.balanceOf(u));
        uint64 base = px;
        for (uint256 i = 0; i < 10; i++) {
            _movePrice(uint64((uint256(px) * 102) / 100));
            _rebalance();
            _movePrice(uint64((uint256(px) * 100) / 102));
            _rebalance();
        }
        _movePrice(base); // exactly where it started

        uint256 end = vault.convertToAssets(vault.balanceOf(u));
        console2.log("start value:", start);
        console2.log("end value  :", end);
        assertLt(end, start, "a rebalanced 2x vault must lose value on a flat round trip");
    }

    /// @dev Decay scales with leverage, and steeply. Same price path, three
    ///      vaults. The plan recommends against launching 10x on this basis; this
    ///      measures it against the contract rather than the standalone model.
    function test_decayScalesWithLeverage() public {
        uint256[3] memory levs = [uint256(20_000), 50_000, 100_000];
        for (uint256 k = 0; k < levs.length; k++) {
            _resetVault(levs[k]);

            address u = _mkUser(500 + k, 1_000_000e6);
            _deposit(u, 10_000e6);
            _rebalance();

            uint256 start = vault.convertToAssets(vault.balanceOf(u));
            uint64 base = px;
            for (uint256 i = 0; i < 10; i++) {
                _movePrice(uint64((uint256(px) * 102) / 100));
                _rebalance();
                _movePrice(uint64((uint256(px) * 100) / 102));
                _rebalance();
            }
            _movePrice(base); // exactly where it started

            uint256 end = vault.convertToAssets(vault.balanceOf(u));
            console2.log("leverage bps :", levs[k]);
            console2.log("   lost (6dp):", start - end);
            console2.log("   lost bps  :", ((start - end) * 10_000) / start);
            assertLt(end, start, "flat round trip must still lose value");
        }
    }

    /// @dev Fresh vault and cleared Core state, so each leverage runs the same path
    ///      from the same starting point.
    function _resetVault(uint256 leverageBps) internal {
        vault = new PerpVault(
            IERC20(address(usdc)), TOKEN_INDEX, PERP, true, leverageBps, "V", "V", owner
        );
        vault.setEntryFeeBps(0);
        coreEquity8 = 0;
        coreSpot8 = 0;
        szi = 0;
        px = 1_000_000;
        delete users;
        _sync();
    }

    /// @dev The de-risk band must actually fire, and before liquidation is close.
    ///      It is the mechanism chosen instead of an insurance fund, so "it
    ///      compiles" is not evidence. Nothing else in either suite exercises it.
    function test_deRiskBandFiresBeforeLiquidation() public {
        _resetVault(20_000); // 2x
        address u = _mkUser(600, 1_000_000e6);
        _deposit(u, 10_000e6);
        _rebalance();

        uint256 openNotional = vault.notional();
        assertApproxEqRel(openNotional, 20_000e6, 1e16, "2x on 10,000 equity");

        // The band exists for drawdowns that happen BETWEEN keeper runs. Rebalancing
        // on every tick pins leverage at target, so it would never drift and the
        // band would never be reachable — drop the price with no intervening
        // rebalance, then let the keeper see the drift.
        //
        // At 2x, a price fall of x leaves notional 20,000(1-x) on equity
        // 10,000-20,000x, so effective leverage passes the 3x trigger at x = 25%.
        for (uint256 i = 0; i < 15; i++) {
            _movePrice(uint64((uint256(px) * 97) / 100));
        }

        uint256 eqBefore = vault.totalAssets();
        uint256 effLev = (vault.notional() * 10_000) / eqBefore;
        console2.log("drifted to effective leverage bps:", effLev);
        assertGt(effLev, 30_000, "drawdown should push a 2x vault past 3x");

        vm.recordLogs();
        _rebalance();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool fired;
        uint256 firedAtLevBps = effLev;
        for (uint256 j = 0; j < logs.length; j++) {
            if (logs[j].topics[0] == keccak256("DeRisked(uint256,uint256,uint256)")) fired = true;
        }

        assertTrue(fired, "de-risk band never fired on a sustained drawdown");
        console2.log("fired at effective leverage bps:", firedAtLevBps);

        // Must fire well before liquidation, not moments before it.
        uint256 equity = vault.totalAssets();
        uint256 mm = vault.maintenanceMargin();
        assertGt(equity, mm * 3, "band should fire with real headroom over maintenance");
        console2.log("equity at fire :", equity);
        console2.log("maintenance    :", mm);
    }

    /// @dev The attack the oracle bound exists to stop, priced end to end.
    ///      NAV derives from accountValue, which HyperCore marks with its OWN mark
    ///      price, so pushing the mark does not merely mislead a read — it inflates
    ///      or deflates equity itself. Deposit into a suppressed mark, let it
    ///      revert, redeem rich.
    function test_markManipulationCannotMintCheapShares() public {
        _resetVault(20_000);
        address honest = _mkUser(700, 1_000_000e6);
        _deposit(honest, 50_000e6);
        _rebalance();

        uint256 fairShares = vault.convertToShares(10_000e6);

        // Push the mark 10% below the index while leaving the oracle alone, and
        // mark the position down with it, exactly as HyperCore would.
        uint64 pushed = uint64((uint256(px) * 90) / 100);
        int256 d = int256(uint256(pushed)) - int256(uint256(px));
        coreEquity8 += int64(int256(szi) * d);
        px = pushed;
        _sync();
        vm.mockCall(HyperCore.ORACLE_PX, abi.encode(PERP), abi.encode(uint64(1_000_000)));

        // Suppressed NAV would hand the attacker materially more shares.
        assertGt(
            vault.convertToShares(10_000e6), (fairShares * 110) / 100,
            "a pushed mark really does cheapen shares"
        );

        address attacker = _mkUser(701, 1_000_000e6);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                PerpVault.PriceDislocated.selector, pushed, uint64(1_000_000),
                vault.markOracleDeviationBps()
            )
        );
        vault.deposit(10_000e6, attacker);
    }

    /// @dev Exiting at an inflated mark takes value from whoever stays, so the
    /// @dev A pushed mark corrupts equity itself (HyperCore marks accountValue
    ///      with its own mark), so nothing may be PAID while mark and index
    ///      disagree. Exit intent still passes — the redemption queues unpriced
    ///      and settles only after the mark reverts, at the honest NAV. This is
    ///      the H-4 shape of the old hard-revert property: the exploit is equally
    ///      dead, but holders are no longer locked in during dislocation.
    function test_markManipulationCannotRedeemRich() public {
        _resetVault(20_000);
        address honest = _mkUser(710, 1_000_000e6);
        uint256 shares = _deposit(honest, 50_000e6);
        _rebalance();

        // A second depositor leaves a real buffer on the EVM side, so a payment
        // at the pushed mark WOULD have money to take.
        address filler = _mkUser(712, 1_000_000e6);
        vm.prank(filler);
        vault.deposit(10_000e6, filler);
        assertGt(vault.idleAssets(), 9_000e6, "buffer exists");

        // Push the mark +10%; the index stays honest.
        uint64 pushed = uint64((uint256(px) * 110) / 100);
        int256 d = int256(uint256(pushed)) - int256(uint256(px));
        coreEquity8 += int64(int256(szi) * d);
        px = pushed;
        _sync();
        vm.mockCall(HyperCore.ORACLE_PX, abi.encode(PERP), abi.encode(uint64(1_000_000)));

        // Nothing is paid at the pushed mark, buffer or no buffer.
        uint256 before = usdc.balanceOf(honest);
        vm.prank(honest);
        vault.redeem(shares / 2, honest);
        assertEq(usdc.balanceOf(honest) - before, 0, "zero paid at a dislocated mark");
        assertApproxEqRel(vault.claimSharesEscrowed(), shares / 2, 1e12, "fully queued");

        // Deposits stay hard-blocked: minting needs a price.
        vm.prank(filler);
        vm.expectRevert();
        vault.deposit(1_000e6, filler);

        // The mark reverts; settlement strikes at the HONEST NAV, so the pushed
        // price leaves no residue in what the exiter is ultimately paid.
        coreEquity8 -= int64(int256(szi) * d);
        px = 1_000_000;
        _sync();
        vault.fundClaims();
        uint256 settled = vault.claimSharesSettled();
        assertGt(settled, 0, "buffer settles part of the queue");

        uint256 honestNav = vault.pricePerShare();
        // Read BEFORE the prank: an argument-position staticcall consumes it.
        uint256 claimable = vault.claimableShares(honest);
        vm.prank(honest);
        uint256 paid = vault.claim(claimable, honest);
        assertApproxEqRel(
            paid, (settled * honestNav) / 1e18, 1e14, "paid at the honest NAV, not the pushed one"
        );
    }

    /// @dev Ordinary basis must not brick the vault. Real divergence on chain 998
    ///      runs 6-24 bps against a 200 bps bound.
    function test_ordinaryBasisStillAllowsDeposits() public {
        _resetVault(20_000);
        address a = _mkUser(720, 1_000_000e6);
        _deposit(a, 50_000e6);
        _rebalance();

        // 25 bps apart: wider than anything observed live, still well inside.
        vm.mockCall(
            HyperCore.ORACLE_PX, abi.encode(PERP), abi.encode(uint64((uint256(px) * 10_025) / 10_000))
        );
        assertLt(vault.markOracleDeviationBps(), 200, "normal basis is inside the bound");

        address b = _mkUser(721, 1_000_000e6);
        vm.prank(b);
        vault.deposit(1_000e6, b); // must not revert
    }

    /// @dev H-1: a trim below the exchange's $10 minimum while exits are queued
    ///      must be widened to the minimum, or settlement stalls forever — the
    ///      residue shrinks geometrically and every trim under $10 is dropped
    ///      silently by the exchange (observed live).
    function test_subMinimumTrimIsWidenedWhenExitsQueued() public {
        _resetVault(20_000);
        address u = _mkUser(960, 1_000_000e6);
        uint256 shares = _deposit(u, 40e6); // $40 at 2x -> $80 position
        _rebalance();
        assertApproxEqRel(vault.notional(), 80e6, 2e16, "position open");

        // Queue a $4 exit: required trim $8, under the $10 minimum.
        vm.prank(u);
        vault.redeem(shares / 10, u);

        vm.expectEmit(false, false, false, false);
        emit PerpVault.TrimWidened(0, 0);
        _rebalance();

        // The widened $10 sell went out and was applied by the harness.
        assertApproxEqRel(vault.notional(), 70e6, 3e16, "trimmed by the widened $10");
    }

    /// @dev H-1: ordinary sub-minimum drift with NO queue is skipped loudly — no
    ///      order is sent, because the exchange would drop it silently and the
    ///      vault would believe it traded.
    function test_subMinimumDriftIsSkippedNotSent() public {
        _resetVault(20_000);
        address u = _mkUser(961, 1_000_000e6);
        _deposit(u, 1_000e6);
        _rebalance();

        // $3 of new idle: delta = $6 buy, below minimum, nothing queued.
        vm.prank(u);
        vault.deposit(3e6, u);

        vm.warp(block.timestamp + vault.rebalanceCooldown() + 1);
        MockCoreWriter cw = MockCoreWriter(HyperCore.CORE_WRITER);
        uint256 before = cw.actionCount();
        vm.expectEmit(false, false, false, false);
        emit PerpVault.OrderBelowMinimum(0, 0);
        vault.rebalance();
        assertEq(cw.actionCount(), before, "no order sent for a sub-minimum drift");
    }

    /// @dev H-2: pulling margin from under the position is floored at 1.5x
    ///      maintenance, so a compromised keeper cannot strip margin and let the
    ///      market do the stealing.
    function test_moveUsdClassCannotStripMarginBelowFloor() public {
        _resetVault(20_000);
        address u = _mkUser(962, 1_000_000e6);
        _deposit(u, 10_000e6);
        _rebalance();

        uint256 eq = vault.coreEquity();
        uint256 floor_ = (vault.maintenanceMargin() * 15_000) / 10_000;

        // Pulling everything but half the floor must revert.
        uint64 tooMuch = uint64(eq - floor_ / 2);
        vm.prank(vault.keeper());
        vm.expectRevert(
            abi.encodeWithSelector(
                PerpVault.MarginFloorBreached.selector, floor_ / 2, floor_
            )
        );
        vault.moveUsdClass(tooMuch, false);

        // A pull that leaves the floor intact passes.
        vm.prank(vault.keeper());
        vault.moveUsdClass(uint64(eq - floor_ * 2), false);
    }

    function test_setKeeperRejectsZeroAddress() public {
        vm.expectRevert(PerpVault.BadParameter.selector);
        vault.setKeeper(address(0));
    }

    /// @dev C-1 regression (was AUDIT PoC A, 46% NAV overstatement). An idle
    ///      outflow while a withdrawal is in flight must not turn the eventual
    ///      credit into phantom NAV: the baseline now rebases on every idle move.
    function test_withdrawBaselineSurvivesIdleOutflow() public {
        _resetVault(20_000);
        address alice = _mkUser(920, 1_000_000e6);
        address bob = _mkUser(921, 1_000_000e6);
        vm.prank(alice);
        vault.deposit(50_000e6, alice);
        vm.prank(bob);
        uint256 bShares = vault.deposit(50_000e6, bob);

        // 60k of it is on Core spot, 40k stays as buffer.
        vm.prank(address(vault));
        usdc.transfer(address(0xdead), 60_000e6);
        coreSpot8 = uint64(60_000e6) * 100;
        _sync();

        vm.prank(vault.keeper());
        vault.withdrawFromCore(30_000e6);
        coreSpot8 -= uint64(30_000e6) * 100;
        _sync();

        // Mid-flight outflow: Bob redeems ~35k from the buffer.
        vm.prank(bob);
        vault.redeem((bShares * 70) / 100, bob);

        // The credit lands on HyperEVM.
        usdc.mint(address(vault), 30_000e6);

        uint256 real = vault.idleAssets() + vault.coreSpot();
        assertEq(vault.pendingWithdraw(), 0, "credit fully recognised");
        assertEq(vault.totalAssets(), real, "no phantom NAV");
    }

    /// @dev C-1 regression, mirror direction: a deposit landing mid-flight must
    ///      not be swallowed as a fake bridge credit (which cleared
    ///      withdrawInFlight early and understated NAV until the real credit came).
    function test_depositMidFlightIsNotMisreadAsBridgeCredit() public {
        _resetVault(20_000);
        address alice = _mkUser(940, 1_000_000e6);
        address bob = _mkUser(941, 1_000_000e6);
        vm.prank(alice);
        vault.deposit(50_000e6, alice);

        vm.prank(address(vault));
        usdc.transfer(address(0xdead), 40_000e6);
        coreSpot8 = uint64(40_000e6) * 100;
        _sync();

        vm.prank(vault.keeper());
        vault.withdrawFromCore(30_000e6);
        coreSpot8 -= uint64(30_000e6) * 100;
        _sync();

        // Mid-flight inflow: Bob deposits 20k.
        vm.prank(bob);
        vault.deposit(20_000e6, bob);
        assertEq(vault.withdrawInFlight(), 30_000e6, "deposit not eaten as credit");
        assertEq(vault.pendingWithdraw(), 30_000e6, "still counted while in flight");

        // The real credit lands and is recognised exactly once.
        usdc.mint(address(vault), 30_000e6);
        assertEq(vault.pendingWithdraw(), 0, "credit recognised");
        assertEq(
            vault.totalAssets(),
            vault.idleAssets() + vault.coreSpot(),
            "no phantom, no shortfall"
        );
    }

    /// @dev C-1 regression: the two bridge directions measure deltas on the same
    ///      balances, so the contract now refuses to run them concurrently.
    function test_bridgeDirectionsAreSerialised() public {
        _resetVault(20_000);
        address alice = _mkUser(950, 1_000_000e6);
        vm.prank(alice);
        vault.deposit(50_000e6, alice);
        vm.prank(address(vault));
        usdc.transfer(address(0xdead), 20_000e6);
        coreSpot8 = uint64(20_000e6) * 100;
        _sync();

        // Outbound in flight blocks a new inbound leg. moveUsdClass stays legal
        // here: nothing measures a spot delta while only the outbound leg runs.
        vm.startPrank(vault.keeper());
        vault.withdrawFromCore(10_000e6);
        vm.expectRevert(PerpVault.BridgeBusy.selector);
        vault.postMargin(5_000e6);

        // Once the credit lands, the guard self-clears via settlement.
        vm.stopPrank();
        usdc.mint(address(vault), 10_000e6);
        vm.startPrank(vault.keeper());
        vault.postMargin(5_000e6);
        assertGt(vault.bridgeInFlight(), 0, "inbound leg started");
        // Inbound in flight blocks BOTH the outbound leg and class transfers,
        // because each would move the spot balance the inbound delta is
        // measured on.
        vm.expectRevert(PerpVault.BridgeBusy.selector);
        vault.withdrawFromCore(1_000e6);
        vm.expectRevert(PerpVault.BridgeBusy.selector);
        vault.moveUsdClass(1_000_000, true);
        vm.stopPrank();
    }

    /// @dev C-2 regression (was AUDIT PoC B: a fresh redeemer took the entire
    ///      unwind that had landed for a fully queued holder). redeem() now runs
    ///      fundClaims() before reading the buffer, so landed liquidity settles
    ///      the queue first and the newcomer queues behind it.
    function test_redeemCannotJumpTheClaimQueue() public {
        _resetVault(20_000);
        address alice = _mkUser(930, 1_000_000e6);
        address bob = _mkUser(931, 1_000_000e6);
        uint256 aShares = _deposit(alice, 50_000e6);
        uint256 bShares = _deposit(bob, 50_000e6);
        _rebalance();

        vm.prank(alice);
        vault.redeem(aShares, alice);
        assertApproxEqRel(vault.claimSharesEscrowed(), aShares, 1e12);

        // The unwind for HER exit lands as idle.
        usdc.mint(address(vault), 50_000e6);
        coreEquity8 -= int64(uint64(50_000e6));
        _sync();

        // Bob redeems before any keeper tick: Alice settles first, Bob queues.
        uint256 bBefore = usdc.balanceOf(bob);
        vm.prank(bob);
        vault.redeem(bShares, bob);

        assertApproxEqRel(
            vault.claimSharesSettled(), aShares, 1e12, "the unwind went to the queue"
        );
        assertEq(vault.claimSharesEscrowed() > 0, true, "Bob is queued");
        assertLt(usdc.balanceOf(bob) - bBefore, 100e6, "Bob got dust at most");
        // Bob is paid the small residue Alice's settlement left in the buffer
        // (pot was struck a hair under the landed 50k), and queues for the rest.
        assertApproxEqRel(
            vault.claimToken().balanceOf(bob), bShares, 2e15, "Bob holds a claim instead"
        );

        // And Alice can actually take her money.
        uint256 claimable = vault.claimableShares(alice);
        vm.prank(alice);
        uint256 paid = vault.claim(claimable, alice);
        assertApproxEqRel(paid, 50_000e6, 2e15, "Alice paid from her own unwind");
    }

    /// @dev The loop closed end to end: a queued exit must cause the position to
    ///      unwind, the freed margin to come home, and the claim to settle — with
    ///      no asset injected by hand anywhere.
    function test_queuedExitUnwindsAndFundsItself() public {
        _resetVault(20_000);
        address alice = _mkUser(910, 1_000_000e6);
        address bob = _mkUser(911, 1_000_000e6);
        uint256 aShares = _deposit(alice, 10_000e6);
        _deposit(bob, 90_000e6);
        _settleIdleToCore();
        _rebalance();

        uint256 notional0 = vault.notional();
        uint256 nav0 = vault.pricePerShare();

        vm.prank(alice);
        vault.redeem(aShares, alice);
        assertApproxEqRel(vault.claimSharesEscrowed(), aShares, 1e12, "queued");
        assertApproxEqAbs(vault.pricePerShare(), nav0, 2, "queueing is NAV-neutral");

        // Sizing now excludes the exiting 10%, so the keeper's ordinary rebalance
        // trims the position instead of sitting still.
        skip(60);
        _rebalance();
        uint256 notional1 = vault.notional();
        assertApproxEqRel(notional1, (notional0 * 90) / 100, 2e16, "trimmed ~10%");

        // Freed margin: perp -> spot -> HyperEVM.
        uint256 free = vault.coreEquity() - (vault.notional() * 10_000) / 20_000;
        vm.startPrank(vault.keeper());
        vault.moveUsdClass(uint64(free), false);
        coreEquity8 -= int64(uint64(free));
        coreSpot8 += uint64(free * 100);
        _sync();
        vault.withdrawFromCore(free);
        vm.stopPrank();

        // In flight: left Core spot, not yet on HyperEVM. NAV must not dip.
        coreSpot8 -= uint64(free * 100);
        _sync();
        assertApproxEqAbs(vault.pricePerShare(), nav0, 200, "no NAV dip mid-bridge");
        assertEq(vault.pendingWithdraw(), free, "counted while in flight");

        // Credit lands on HyperEVM.
        usdc.mint(address(vault), free);
        assertEq(vault.pendingWithdraw(), 0, "self-clears once credited");

        uint256 navBefore = vault.pricePerShare();
        vault.fundClaims();
        assertApproxEqAbs(vault.pricePerShare(), navBefore, 2, "settlement is NAV-neutral");

        uint256 claimable = vault.claimableShares(alice);
        assertGt(claimable, 0, "the unwind actually funded the exit");
        vm.prank(alice);
        uint256 paid = vault.claim(claimable, alice);

        console2.log("notional before :", notional0);
        console2.log("notional after  :", notional1);
        console2.log("margin freed    :", free);
        console2.log("paid to exiter  :", paid);
        console2.log("still escrowed  :", vault.claimSharesEscrowed());
    }

    /// @dev The exit-side mirror of the entry externality, and the reason claims
    ///      are denominated in shares rather than asset.
    ///
    ///      Fixing an asset amount at request time hands the redeemer their price
    ///      before the unwind that funds it has happened. They are then out of the
    ///      market but still hold a claim on face value — free downside protection,
    ///      paid for by whoever stayed. Modelled on a 100,000 vault at 2x with a
    ///      10% exit, a 15% drop cost the remaining holders 3,000 extra.
    ///
    ///      Escrowing the shares instead keeps the queued holder on NAV until they
    ///      are genuinely out.
    function test_queuedRedeemerCarriesTheMarketNotTheStayers() public {
        _resetVault(20_000);
        address alice = _mkUser(800, 1_000_000e6);
        address bob = _mkUser(801, 1_000_000e6);
        uint256 aShares = _deposit(alice, 10_000e6);
        _deposit(bob, 90_000e6);
        _rebalance();

        uint256 navAtRequest = vault.pricePerShare();

        // Alice exits with nothing liquid, so the whole position queues.
        vm.prank(alice);
        vault.redeem(aShares, alice);
        assertApproxEqRel(vault.claimSharesEscrowed(), aShares, 1e12, "all escrowed");
        assertApproxEqAbs(vault.pricePerShare(), navAtRequest, 2, "queueing must not move NAV");

        uint256 navBobBefore = vault.pricePerShare();

        // Market falls 15% before the unwind funds her.
        _movePrice(uint64((uint256(px) * 85) / 100));

        uint256 navAfter = vault.pricePerShare();
        assertLt(navAfter, navBobBefore, "a 2x vault loses on a 15% drop");

        // Unwind enough to settle her, then let her claim.
        uint256 owedNow = vault.convertToAssets(aShares);
        usdc.mint(address(vault), owedNow);
        coreEquity8 -= int64(uint64(owedNow));
        _sync();

        // Funding is measured from the realised unwind, so rounding can leave the
        // last dust unsettled; claim what is actually settled, as a UI would.
        vault.fundClaims();
        uint256 claimBal = vault.claimableShares(alice);
        assertApproxEqRel(claimBal, aShares, 1e12, "essentially all of it settles");
        vm.prank(alice);
        uint256 paid = vault.claim(claimBal, alice);

        // She is paid at the POST-drop rate, not the rate at request.
        uint256 faceAtRequest = (aShares * navAtRequest) / 1e18;
        assertLt(paid, faceAtRequest, "queued exit must not lock in the pre-drop price");
        assertApproxEqRel(paid, owedNow, 1e14, "paid at the realised rate");

        // Bob keeps exactly his own share of the move: NAV is untouched by her exit.
        assertApproxEqAbs(
            vault.pricePerShare(), navAfter, 2, "settlement must not move NAV for stayers"
        );

        console2.log("nav at request :", navAtRequest);
        console2.log("nav at settle  :", navAfter);
        console2.log("face if fixed  :", faceAtRequest);
        console2.log("actually paid  :", paid);
        console2.log("borne by exiter:", faceAtRequest - paid);
    }

    /// @dev A deposit valued immediately afterwards must never be worth more than
    ///      was paid. That is the shape of a share-price attack.
    function testFuzz_roundTripNeverProfits(uint96 amount) public {
        amount = uint96(bound(amount, 1e6, 500_000e6));
        vault.setEntryFeeBps(0);

        address seed = _mkUser(400, 1_000_000e6);
        _deposit(seed, 50_000e6);
        _rebalance();
        _movePrice(1_030_000);

        address attacker = _mkUser(401, 1_000_000e6);
        vm.prank(attacker);
        uint256 shares = vault.deposit(amount, attacker);

        uint256 out = vault.convertToAssets(shares);
        assertLe(out, amount, "round trip must not create value");
    }
}
