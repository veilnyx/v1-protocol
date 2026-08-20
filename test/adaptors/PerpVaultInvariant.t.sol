// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PerpVault} from "src/adaptors/hyperliquid/PerpVault.sol";
import {HyperCore} from "src/adaptors/hyperliquid/IHyperCore.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockCoreWriter} from "test/mocks/MockHyperCorePrecompiles.sol";

/// @notice Random interleavings of every operation the vault supports, against a
///         stateful mocked Core, with ghost accounting as ground truth. C-1
///         (phantom NAV from the withdraw baseline) lived exactly in an
///         interleaving no directed test tried — idle moving while a bridge leg
///         was in flight — and invariant_reportedGrossMatchesReality would have
///         caught it on the first run.
contract PerpVaultHandler is CommonBase, StdCheats, StdUtils {
    uint32 constant PERP = 3;
    uint64 constant TOKEN_INDEX = 0;
    uint256 constant TAKER_FEE_BPS = 45; // hundredths of a bp, /100_000

    PerpVault public vault;
    MockERC20 public usdc;
    address[] public users;

    // The mocked Core account. coreEquity6 follows the chain convention:
    // accountValue is 1e6 perp-USD, same scale as 6dp USDC.
    int256 public coreEquity6;
    uint64 public coreSpot8;
    int64 public szi;
    uint64 public px = 1_000_000; // $100k BTC, szDecimals 5

    // Ghost ground truth.
    uint256 public ghostDeposited;
    uint256 public ghostPaidOut;
    int256 public ghostPnl6;
    uint256 public ghostFees6;
    uint256 public ghostInFlightIn; // bridged in, Core credit not yet landed
    uint256 public ghostInFlightOut; // spot sent back, EVM credit not yet landed

    constructor() {
        usdc = new MockERC20(address(this), 6);
        vault = new PerpVault(
            IERC20(address(usdc)), TOKEN_INDEX, PERP, true, 20_000, "BTC Long 2x", "vBTC2L", address(this)
        );
        MockCoreWriter cw = new MockCoreWriter();
        vm.etch(HyperCore.CORE_WRITER, address(cw).code);
        for (uint256 i = 0; i < 5; i++) {
            users.push(vm.addr(0xA11CE + i));
        }
        _sync();
    }

    function _sync() internal {
        int64 av = coreEquity6 > int256(type(int64).max)
            ? type(int64).max
            : (coreEquity6 < int256(type(int64).min) ? type(int64).min : int64(coreEquity6));
        vm.mockCall(
            HyperCore.MARGIN_SUMMARY,
            abi.encode(uint32(0), address(vault)),
            abi.encode(HyperCore.MarginSummary(av, 0, 0, int64(0)))
        );
        vm.mockCall(
            HyperCore.POSITION,
            abi.encode(address(vault), PERP),
            abi.encode(HyperCore.Position(szi, 0, 0, 10, false))
        );
        vm.mockCall(HyperCore.MARK_PX, abi.encode(PERP), abi.encode(px));
        vm.mockCall(HyperCore.ORACLE_PX, abi.encode(PERP), abi.encode(px));
        vm.mockCall(
            HyperCore.SPOT_BALANCE,
            abi.encode(address(vault), TOKEN_INDEX),
            abi.encode(HyperCore.SpotBalance(coreSpot8, 0, 0))
        );
        vm.mockCall(
            HyperCore.PERP_ASSET_INFO,
            abi.encode(PERP),
            abi.encode(HyperCore.PerpAssetInfo("BTC", uint32(54), uint8(5), uint8(40), false))
        );
        vm.mockCall(
            HyperCore.BBO, abi.encode(PERP), abi.encode(HyperCore.Bbo({bid: px - 50, ask: px + 50}))
        );
    }

    function _user(uint256 seed) internal view returns (address) {
        return users[seed % users.length];
    }

    /// @dev Reported gross (totalAssets + pot) must equal physically-existing
    ///      asset. Checked after EVERY action, not only between runs.
    function _checkGross() internal view {
        uint256 reported = vault.totalAssets() + vault.claimPot();
        uint256 real_ = usdc.balanceOf(address(vault))
            + (coreEquity6 > 0 ? uint256(coreEquity6) : 0) + uint256(coreSpot8) / 100
            + ghostInFlightIn + ghostInFlightOut;
        require(reported == real_, "PHANTOM: reported gross != physical asset");
    }

    // ------------------------------------------------------------- actions

    function deposit(uint256 seed, uint256 amt) external {
        amt = bound(amt, 1e6, 100_000e6);
        if (vault.depositsFrozen() || vault.isDistressed()) return;
        address u = _user(seed);
        usdc.mint(u, amt);
        vm.prank(u);
        usdc.approve(address(vault), amt);
        vm.prank(u);
        vault.deposit(amt, u);
        ghostDeposited += amt;
        _checkGross();
    }

    function redeem(uint256 seed, uint256 pct) external {
        pct = bound(pct, 1, 100);
        address u = _user(seed);
        uint256 shares = (vault.balanceOf(u) * pct) / 100;
        if (shares == 0) return;
        uint256 before = usdc.balanceOf(u);
        uint256 pps = vault.pricePerShare();
        vm.prank(u);
        vault.redeem(shares, u);
        // Directional NAV-neutrality. Floor rounding may leave DUST to the
        // stayers (bounded by a couple of asset units spread over the supply,
        // which is large per-share when the supply is small); it must never
        // take from them.
        _requireNavNeutral(pps, "redeem");
        ghostPaidOut += usdc.balanceOf(u) - before;
        _checkGross();
    }

    function claimAction(uint256 seed) external {
        address u = _user(seed);
        uint256 claimable = vault.claimableShares(u);
        if (claimable == 0) return;
        uint256 before = usdc.balanceOf(u);
        vm.prank(u);
        vault.claim(claimable, u);
        ghostPaidOut += usdc.balanceOf(u) - before;
        _checkGross();
    }

    function fundClaimsAction() external {
        uint256 pps = vault.pricePerShare();
        vault.fundClaims();
        _requireNavNeutral(pps, "fundClaims");
        _checkGross();
    }

    function postMargin(uint256 pct) external {
        pct = bound(pct, 1, 100);
        if (vault.withdrawInFlight() > 0) return; // BridgeBusy by design
        uint256 bridgeable =
            vault.idleAssets() > vault.claimPot() ? vault.idleAssets() - vault.claimPot() : 0;
        uint256 amt = (bridgeable * pct) / 100;
        if (amt == 0) return;
        // The vault settles the inbound leg before re-baselining; mirror the
        // class transfer that settlement performs on the mocked Core. credited =
        // inFlightBefore + amt - inFlightAfter, since the mock spot only moves
        // when this handler moves it.
        uint256 inFlightBefore = vault.bridgeInFlight();
        vault.postMargin(amt);
        uint256 settled = inFlightBefore + amt - vault.bridgeInFlight();
        if (settled > 0) {
            coreSpot8 -= uint64(settled * 100);
            coreEquity6 += int256(settled);
            _sync();
        }
        ghostInFlightIn += amt;
        _checkGross();
    }

    function landBridgeCredit(uint256 pct) external {
        pct = bound(pct, 1, 100);
        uint256 x = (ghostInFlightIn * pct) / 100;
        if (x == 0) return;
        // Core credits the spot balance; the ERC20 sent to the system address is
        // consumed by the bridge (burn the mirror the mock kept).
        coreSpot8 += uint64(x * 100);
        ghostInFlightIn -= x;
        _sync();
        _checkGross();
    }

    function settleBridgeAction() external {
        uint256 credited = vault.settleBridge();
        if (credited > 0) {
            // The class transfer the vault just queued: spot -> perp.
            coreSpot8 -= uint64(credited * 100);
            coreEquity6 += int256(credited);
            _sync();
        }
        _checkGross();
    }

    function withdrawFromCore(uint256 pct) external {
        pct = bound(pct, 1, 100);
        if (vault.bridgeInFlight() > 0) return; // BridgeBusy by design
        uint256 amt = (uint256(coreSpot8) / 100 * pct) / 100;
        if (amt == 0) return;
        vault.withdrawFromCore(amt);
        // Core debits spot now; the EVM credit lands later.
        coreSpot8 -= uint64(amt * 100);
        ghostInFlightOut += amt;
        _sync();
        _checkGross();
    }

    function landWithdrawCredit(uint256 pct) external {
        pct = bound(pct, 1, 100);
        uint256 x = (ghostInFlightOut * pct) / 100;
        if (x == 0) return;
        usdc.mint(address(vault), x);
        ghostInFlightOut -= x;
        _checkGross();
    }

    function settleWithdrawAction() external {
        vault.settleWithdraw();
        _checkGross();
    }

    function moveUsdClassDown(uint256 pct) external {
        pct = bound(pct, 1, 90);
        if (vault.bridgeInFlight() > 0) return;
        uint256 eq = vault.coreEquity();
        uint256 floor_ = (vault.maintenanceMargin() * 15_000) / 10_000;
        if (eq <= floor_) return;
        uint256 amt = ((eq - floor_) * pct) / 100;
        if (amt == 0) return;
        vault.moveUsdClass(uint64(amt), false);
        coreEquity6 -= int256(amt);
        coreSpot8 += uint64(amt * 100);
        _sync();
        _checkGross();
    }

    function movePrice(uint256 newPxSeed) external {
        uint64 newPx = uint64(bound(newPxSeed, (uint256(px) * 90) / 100, (uint256(px) * 110) / 100));
        if (newPx == px || newPx == 0) return;
        int256 pnl6 = int256(szi) * (int256(uint256(newPx)) - int256(uint256(px)));
        // Do not model liquidation here: this suite is about accounting. Skip
        // moves that would push the account through its maintenance boundary.
        if (coreEquity6 + pnl6 <= int256(vault.maintenanceMargin())) return;
        coreEquity6 += pnl6;
        ghostPnl6 += pnl6;
        px = newPx;
        _sync();
        _checkGross();
    }

    function rebalanceAction() external {
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

        // The real exchange drops sub-$10 notionals silently.
        if ((uint256(sz) * uint256(pxWire)) / 1e10 < 10e6) return;

        int64 szRead = int64(sz / uint64(10 ** 3)); // 8 wire - 5 szDecimals
        uint256 traded6 = uint256(uint64(szRead >= 0 ? szRead : -szRead)) * uint256(px);
        uint256 fee6 = (traded6 * TAKER_FEE_BPS) / 100_000;
        // The exchange also rejects orders the account cannot margin. The vault
        // sizes off totalAssets, which includes idle equity NOT yet posted to
        // Core, so it will happily order before margin arrives — modelling that
        // fill would let a position exist on zero margin and negative equity.
        int64 sziAfter = szi + (isBuy ? szRead : -szRead);
        uint256 notionalAfter = uint256(uint64(sziAfter >= 0 ? sziAfter : -sziAfter)) * uint256(px);
        if (coreEquity6 - int256(fee6) < int256(notionalAfter / 40)) return;
        szi = sziAfter;
        coreEquity6 -= int256(fee6);
        ghostFees6 += fee6;
        _sync();
        _checkGross();
    }

    // ------------------------------------------------------------- helpers

    function _requireNavNeutral(uint256 ppsBefore, string memory op) internal view {
        uint256 ppsAfter = vault.pricePerShare();
        // Never down beyond integer dust: that would be taking from stayers.
        require(ppsAfter + 2 >= ppsBefore, string.concat(op, " stole from stayers"));
        // Up only by rounding dust: a few asset units spread over the supply.
        uint256 dustUp = ((4 * 1e18) / (vault.totalSupply() + 1e12)) + 2;
        require(ppsAfter <= ppsBefore + dustUp, string.concat(op, " gifted beyond dust"));
    }

    function realGross() external view returns (uint256) {
        return usdc.balanceOf(address(vault)) + (coreEquity6 > 0 ? uint256(coreEquity6) : 0)
            + uint256(coreSpot8) / 100 + ghostInFlightIn + ghostInFlightOut;
    }
}

contract PerpVaultInvariantTest is Test {
    PerpVaultHandler handler;
    PerpVault vault;

    function setUp() public {
        handler = new PerpVaultHandler();
        vault = handler.vault();
        targetContract(address(handler));
    }

    /// @dev (i) The C-1 class: everything the vault REPORTS must physically
    ///      exist somewhere. Phantom NAV — from a corrupted bridge baseline, a
    ///      double-counted credit, anything — breaks this.
    function invariant_reportedGrossMatchesReality() public view {
        assertEq(
            vault.totalAssets() + vault.claimPot(),
            handler.realGross(),
            "reported asset does not physically exist"
        );
    }

    /// @dev (iv) Flow conservation: what exists equals what came in, minus what
    ///      left, adjusted for market PnL and exchange fees. Nothing mints value.
    function invariant_flowConservation() public view {
        int256 expected = int256(handler.ghostDeposited()) - int256(handler.ghostPaidOut())
            + handler.ghostPnl6() - int256(handler.ghostFees6());
        assertEq(int256(handler.realGross()), expected, "value minted or destroyed");
    }

    /// @dev (iii) The pot is a liability payable on demand: it must be covered by
    ///      ERC20 actually on the EVM side, always.
    function invariant_claimPotBacked() public view {
        assertLe(vault.claimPot(), vault.idleAssets(), "pot not payable");
    }

    /// @dev (ii) Escrow discipline: shares in escrow are exactly the shares the
    ///      vault holds, and CLAIM supply is exactly escrowed + settled.
    function invariant_escrowAccounting() public view {
        assertEq(vault.balanceOf(address(vault)), vault.claimSharesEscrowed(), "escrow mismatch");
        assertEq(
            vault.claimToken().totalSupply(),
            vault.claimSharesEscrowed() + vault.claimSharesSettled(),
            "CLAIM supply out of sync"
        );
    }
}
