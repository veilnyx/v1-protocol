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
        // totalAssets() also reads the Core spot balance; this harness keeps all
        // equity in perp, so spot stays flat at zero.
        vm.mockCall(
            HyperCore.SPOT_BALANCE,
            abi.encode(address(vault), TOKEN_INDEX),
            abi.encode(HyperCore.SpotBalance(uint64(0), 0, 0))
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
        (, bool isBuy,, uint64 sz,,,) =
            abi.decode(payload, (uint32, bool, uint64, uint64, bool, uint8, uint128));

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
