// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Asset, AssetType} from "src/libraries/AssetLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {IScreener} from "src/interfaces/IScreener.sol";
import {Screener} from "src/core/Screener.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";
import {MockScreener} from "test/mocks/MockScreener.sol";
import {MockVerifier} from "test/mocks/MockVerifier.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {TVL_USD_DECIMALS, MIN_PRICE_STALENESS_THRESHOLD} from "src/base/Constants.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

/// @dev Unit tests for Pool.setAssetPriceFeed, Pool.setTvlLimitUsd, and Pool.getTvlUsd.
///      PoolTest._setUp() adds 3 ERC20 assets:
///        asset1 (token1, 18 dec), asset2 (token2, 6 dec), asset3 (tokenReent, 18 dec).
///      All three must have a feed registered before calling getTvlUsd().
contract PoolGuardrailsTest is PoolTest {
    MockAggregatorV3 internal mockFeed1; // token1 / WETH-like: 18-dec, $2000
    MockAggregatorV3 internal mockFeed2; // token2 / USDC-like:  6-dec,  $1
    MockAggregatorV3 internal mockFeed3; // tokenReent:          18-dec, $1

    Asset public asset3;
    uint256 internal constant ETH_MAINNET = 1;
    /// @dev Chainalysis sanctions oracle on Ethereum mainnet.
    address internal constant MAINNET_SANCTIONS_LIST =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;
    /// @dev A sanctioned address taken from the mainnet `SanctionedAddressesAdded`
    /// event logs of the Chainalysis oracle.
    address internal constant SANCTIONED_ADDRESS =
        0xFda1Ec4A6178d4916b001a065422D31EBE5F62FF;

    function setUp() public {
        _setUp();

        asset3 = pool.getAsset(address(tokenReent));

        mockFeed1 = new MockAggregatorV3(int256(2000e8), 8); // $2000 / 8-dec feed
        mockFeed2 = new MockAggregatorV3(int256(1e8), 8); // $1    / 8-dec feed
        mockFeed3 = new MockAggregatorV3(int256(1e8), 8); // $1    / 8-dec feed
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setAssetPriceFeed
    // ─────────────────────────────────────────────────────────────────────────

    function test_setTvlPriceFeed() public {
        vm.expectEmit(true, true, false, false);
        emit IPool.AssetUsdPriceFeedSet(
            asset1.id,
            AggregatorV3Interface(address(mockFeed1))
        );

        pool.setAssetPriceFeed(
            asset1.id,
            AggregatorV3Interface(address(mockFeed1))
        );

        assertEq(
            address(pool.getAsset(asset1.id).usdPriceFeed),
            address(mockFeed1)
        );
    }

    function test_revert_setTvlPriceFeed_notOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert();
        pool.setAssetPriceFeed(
            asset1.id,
            AggregatorV3Interface(address(mockFeed1))
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getTvlUsd — helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Mirrors getTvlUsd single-asset math using the feed registered in the pool.
    ///      Works for both mock feeds (local) and real Chainlink feeds (fork).
    function _computeExpectedUsd(
        uint24 assetId,
        uint8 assetDecimals,
        uint256 rawBalance
    ) internal view returns (uint256) {
        AggregatorV3Interface feed = pool.getAsset(assetId).usdPriceFeed;
        uint8 feedDecimals = feed.decimals();
        (, int256 price, , , ) = feed.latestRoundData();
        uint256 baseExp = uint256(assetDecimals) + uint256(feedDecimals);
        if (baseExp <= TVL_USD_DECIMALS) {
            return
                rawBalance *
                uint256(price) *
                10 ** (TVL_USD_DECIMALS - baseExp);
        } else {
            return
                (rawBalance * uint256(price)) /
                10 ** (baseExp - TVL_USD_DECIMALS);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getTvlUsd — happy path
    // ─────────────────────────────────────────────────────────────────────────

    function _registerAllFeeds() internal {
        if (address(pool.getAsset(asset1.id).usdPriceFeed) == address(0)) {
            pool.setAssetPriceFeed(
                asset1.id,
                AggregatorV3Interface(address(mockFeed1))
            );
        }
        if (address(pool.getAsset(asset2.id).usdPriceFeed) == address(0)) {
            pool.setAssetPriceFeed(
                asset2.id,
                AggregatorV3Interface(address(mockFeed2))
            );
        }
        if (address(pool.getAsset(asset3.id).usdPriceFeed) == address(0)) {
            pool.setAssetPriceFeed(
                asset3.id,
                AggregatorV3Interface(address(mockFeed3))
            );
        }
    }

    /// 18-dec token, balance = 1 token. Expected value derived from the registered feed.
    function test_getTvlUsd_singleAsset_18dec() public {
        _registerAllFeeds();
        uint256 balance = 1 ether;
        token1.mint(address(pool), balance);

        uint256 tvl = pool.getTvlUsd();
        assertEq(
            tvl,
            _computeExpectedUsd(asset1.id, asset1.precision, balance)
        );
    }

    /// 6-dec token, balance = 1000 USDC. Expected value derived from the registered feed.
    function test_getTvlUsd_singleAsset_6dec() public {
        _registerAllFeeds();
        uint256 balance = 1000e6;
        token2.mint(address(pool), balance);

        uint256 tvl = pool.getTvlUsd();
        assertEq(
            tvl,
            _computeExpectedUsd(asset2.id, asset2.precision, balance)
        );
    }

    /// Both assets with balances; contributions are summed.
    function test_getTvlUsd_multipleAssets() public {
        _registerAllFeeds();
        uint256 balance1 = 1 ether;
        uint256 balance2 = 1000e6;
        token1.mint(address(pool), balance1);
        token2.mint(address(pool), balance2);

        uint256 expected = _computeExpectedUsd(
            asset1.id,
            asset1.precision,
            balance1
        ) + _computeExpectedUsd(asset2.id, asset2.precision, balance2);
        assertEq(pool.getTvlUsd(), expected);
    }

    /// Zero balance means zero contribution — getTvlUsd returns 0, not revert.
    function test_getTvlUsd_zeroBalance() public {
        _registerAllFeeds();
        assertEq(pool.getTvlUsd(), 0);
    }

    /// Inactive asset is skipped; only the active asset's balance counts.
    function test_getTvlUsd_skipsInactiveAsset() public {
        _registerAllFeeds();
        uint256 balance2 = 1000e6;
        token1.mint(address(pool), 1 ether);
        pool.updateAssetStatus(asset1.id, false);
        token2.mint(address(pool), balance2);

        assertEq(
            pool.getTvlUsd(),
            _computeExpectedUsd(asset2.id, asset2.precision, balance2)
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getTvlUsd — revert paths
    // ─────────────────────────────────────────────────────────────────────────

    /// getTvlUsd skips assets with no feed registered and includes only assets with feeds.
    function test_getTvlUsd_noFeedRegistered_skipsAsset() public {
        pool.setAssetPriceFeed(
            asset1.id,
            AggregatorV3Interface(address(mockFeed2))
        );
        pool.setAssetPriceFeed(
            asset2.id,
            AggregatorV3Interface(address(mockFeed2))
        );
        pool.setAssetPriceFeed(asset3.id, AggregatorV3Interface(address(0)));
        token1.mint(address(pool), 1 ether);
        token2.mint(address(pool), 1000e6);

        // Should not revert — asset1 is skipped (contributes 0), asset2+3 are included.
        uint256 tvl = pool.getTvlUsd();
        assertGt(tvl, 0);
    }

    /// getTvlUsd reverts when the price data is older than priceFeedStalenessThreshold.
    /// Reads updatedAt from the actually registered feed (real on fork, mock on local).
    function test_revert_getTvlUsd_stalePrice() public {
        _registerAllFeeds();
        // Capture updatedAt from the registered feed — works for both mock (local) and real (fork).
        (, , , uint256 updatedAt, ) = pool
            .getAsset(asset1.id)
            .usdPriceFeed
            .latestRoundData();
        // Wind clock past the configured staleness threshold.
        vm.warp(block.timestamp + pool.priceFeedStalenessThreshold() + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.PriceFeedValueStale.selector,
                asset1.id,
                updatedAt
            )
        );
        pool.getTvlUsd();
    }

    /// getTvlUsd reverts when the feed returns a negative price.
    /// Unconditionally overrides asset1's feed with the mock so we can control the price.
    function test_revert_getTvlUsd_negativePrice() public {
        _registerAllFeeds();
        pool.setAssetPriceFeed(
            asset1.id,
            AggregatorV3Interface(address(mockFeed1))
        );
        mockFeed1.setPrice(-1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.PriceFeedValueInvalid.selector,
                asset1.id,
                int256(-1)
            )
        );
        pool.getTvlUsd();
    }

    /// getTvlUsd reverts when the feed returns zero (unusable price).
    /// Unconditionally overrides asset1's feed with the mock so we can control the price.
    function test_revert_getTvlUsd_zeroPrice() public {
        _registerAllFeeds();
        pool.setAssetPriceFeed(
            asset1.id,
            AggregatorV3Interface(address(mockFeed1))
        );
        mockFeed1.setPrice(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.PriceFeedValueInvalid.selector,
                asset1.id,
                int256(0)
            )
        );
        pool.getTvlUsd();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setTvlLimitUsd
    // ─────────────────────────────────────────────────────────────────────────

    function test_setTvlLimitUsd() public {
        uint256 limit = 500_000e6;
        vm.expectEmit(false, false, false, true);
        emit IPool.TvlLimitUpdated(limit);

        pool.setTvlLimitUsd(limit);
        assertEq(pool.tvlLimitUsd(), limit);
    }

    function test_revert_setTvlLimitUsd_notOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert();
        pool.setTvlLimitUsd(500_000e6);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setPriceFeedStalenessThreshold
    // ─────────────────────────────────────────────────────────────────────────

    function test_setPriceFeedStalenessThreshold() public {
        uint256 newThreshold = 2 days;
        vm.expectEmit(false, false, false, true);
        emit IPool.PriceFeedStalenessThresholdUpdated(newThreshold);

        pool.setPriceFeedStalenessThreshold(newThreshold);
        assertEq(pool.priceFeedStalenessThreshold(), newThreshold);
    }

    function test_revert_setPriceFeedStalenessThreshold_notOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert();
        pool.setPriceFeedStalenessThreshold(2 hours);
    }

    function test_revert_setPriceFeedStalenessThreshold_tooLow() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.PriceFeedStalenessThresholdTooLow.selector,
                MIN_PRICE_STALENESS_THRESHOLD - 1,
                MIN_PRICE_STALENESS_THRESHOLD
            )
        );
        pool.setPriceFeedStalenessThreshold(MIN_PRICE_STALENESS_THRESHOLD - 1);
    }

    function test_revert_setPriceFeedStalenessThreshold_zero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.PriceFeedStalenessThresholdTooLow.selector,
                uint256(0),
                MIN_PRICE_STALENESS_THRESHOLD
            )
        );
        pool.setPriceFeedStalenessThreshold(0);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // whenTvlLimitNotCrossed modifier
    // ─────────────────────────────────────────────────────────────────────────

    /// Deposit that pushes TVL above the limit reverts via whenTvlLimitNotCrossed.
    /// Uses deposit_pre_tx (10 000 token1 + 10 000 token2).
    /// With mockFeed1 at $2000 and mockFeed2 at $1, the deposit USD value is:
    ///   10000e18 * 2000e6 / 1e18  +  10000e6 * 1e6 / 1e6  =  20_010_000e6
    /// Setting the limit to $1 ensures any deposit will cross it.
    function test_revert_whenTvlLimitNotCrossed_depositExceedsLimit() public {
        _registerAllFeeds();

        pool.setTvlLimitUsd(1e6); // $1 — any real deposit will cross this

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        // Derive the expected error values from the contract directly.
        uint256 expectedProjectedTvl = pool.getTvlUsd() +
            pool.getDepositUsd(stx);
        bool crossed = pool.isTvlLimitCrossed(stx);
        assertTrue(crossed, "deposit should cross the TVL limit");

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.TvlLimitExceeded.selector,
                expectedProjectedTvl,
                uint256(1e6)
            )
        );
        pool.transact(stx);
    }

    /// Deposit that keeps TVL below the limit succeeds (modifier does not revert).
    function test_whenTvlLimitNotCrossed_depositBelowLimit() public {
        _registerAllFeeds();

        pool.setTvlLimitUsd(500_000_000e6); // $500 M — well above the ~$20 M deposit

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        assertFalse(
            pool.isTvlLimitCrossed(stx),
            "deposit should not cross the TVL limit"
        );
        pool.transact(stx); // must not revert
    }

    /// When tvlLimitUsd is 0 (disabled), isTvlLimitCrossed always returns false
    /// and the modifier never reverts regardless of deposit size.
    function test_whenTvlLimitNotCrossed_disabledWhenLimitIsZero() public {
        _registerAllFeeds();
        // tvlLimitUsd is 0 (set during initialize in tests)

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        assertFalse(
            pool.isTvlLimitCrossed(stx),
            "limit of 0 means guard is disabled"
        );
        pool.transact(stx); // must not revert
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setDepositLimits
    // ─────────────────────────────────────────────────────────────────────────

    function test_setDepositLimits_minOnly() public {
        uint256 minLimit = 5e6; // $5
        vm.expectEmit(false, false, false, true);
        emit IPool.MinDepositUpdated(minLimit);

        pool.setDepositLimits(minLimit, type(uint256).max);
        assertEq(pool.minDepositUsd(), minLimit);
        assertEq(pool.maxDepositUsd(), type(uint256).max);
    }

    function test_setDepositLimits_maxOnly() public {
        uint256 maxLimit = 50e6; // $50
        vm.expectEmit(false, false, false, true);
        emit IPool.MaxDepositUpdated(maxLimit);

        pool.setDepositLimits(0, maxLimit);
        assertEq(pool.minDepositUsd(), 0);
        assertEq(pool.maxDepositUsd(), maxLimit);
    }

    function test_setDepositLimits_both() public {
        uint256 minLimit = 5e6;
        uint256 maxLimit = 50e6;
        vm.expectEmit(false, false, false, true);
        emit IPool.MinDepositUpdated(minLimit);
        vm.expectEmit(false, false, false, true);
        emit IPool.MaxDepositUpdated(maxLimit);

        pool.setDepositLimits(minLimit, maxLimit);
        assertEq(pool.minDepositUsd(), minLimit);
        assertEq(pool.maxDepositUsd(), maxLimit);
    }

    function test_revert_setDepositLimits_notOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert();
        pool.setDepositLimits(5e6, 50e6);
    }

    function test_revert_setDepositLimits_minGtMax() public {
        vm.expectRevert(IPool.BadArguments.selector);
        pool.setDepositLimits(100e6, 1e6); // min > max
    }

    // ─────────────────────────────────────────────────────────────────────────
    // whenDepositWithinLimits modifier
    // ─────────────────────────────────────────────────────────────────────────

    /// deposit_pre_tx deposits ~$20 010 000 (with mockFeed1 at $2000, mockFeed2 at $1).
    /// Setting minDepositUsd above that value must trigger DepositBelowMinimum.
    function test_revert_whenDepositWithinLimits_belowMinimum() public {
        _registerAllFeeds();
        pool.setDepositLimits(25_000_000e6, type(uint256).max); // $25 M > ~$20 M deposit

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        uint256 depositUsd = pool.getDepositUsd(stx);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DepositBelowMinimum.selector,
                depositUsd,
                uint256(25_000_000e6)
            )
        );
        pool.transact(stx);
    }

    /// Setting maxDepositUsd below the deposit value must trigger DepositAboveMaximum.
    function test_revert_whenDepositWithinLimits_aboveMaximum() public {
        _registerAllFeeds();
        pool.setDepositLimits(0, 1_000e6); // $1 000 < ~$20 M deposit

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        uint256 depositUsd = pool.getDepositUsd(stx);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DepositAboveMaximum.selector,
                depositUsd,
                uint256(1_000e6)
            )
        );
        pool.transact(stx);
    }

    /// When both limits bracket the deposit value, transact() must succeed.
    function test_whenDepositWithinLimits_withinRange() public {
        _registerAllFeeds();
        pool.setDepositLimits(1e6, 25_000_000e6); // $1 min, $25 M max — brackets ~$20 M deposit

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        pool.transact(stx); // must not revert
    }

    /// When minDepositUsd and maxDepositUsd are both 0 (default), the limits
    /// are disabled and any deposit size is allowed.
    function test_whenDepositWithinLimits_disabledWhenLimitsAreZero() public {
        _registerAllFeeds();
        // minDepositUsd and maxDepositUsd default to 0

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        pool.transact(stx); // must not revert
    }

    /// TRANSFER transactions must bypass the deposit limit check entirely.
    function test_whenDepositWithinLimits_transferIgnoresLimits() public {
        _makePreDeposit();

        // Set a $1 B minimum — any realistic deposit would be below this and would fail.
        pool.setDepositLimits(1_000_000_000e6, type(uint256).max);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_without_fee"
        );
        pool.transact(stx); // TRANSFER → deposit guard not triggered → success
    }

    /// WITHDRAW transactions must bypass the deposit limit check entirely.
    function test_whenDepositWithinLimits_withdrawIgnoresLimits() public {
        _makePreDeposit();

        pool.setDepositLimits(1_000_000_000e6, type(uint256).max);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_100_weth_without_fee"
        );
        pool.transact(stx); // WITHDRAW → deposit guard not triggered → success
    }

    /// Deposit transaction where asset1 has no registered price feed reverts with
    /// DepositRestrictedAsAssetFeedNotSet when at least one USD limit is enabled.
    /// When all limits are 0 (disabled), deposits proceed without requiring a feed (H-1 fix).
    function test_revert_whenDepositWithinLimits_assetFeedNotSet() public {
        // Explicitly clear feeds — _setUp() registers _defaultMockFeed for all assets.
        pool.setAssetPriceFeed(asset1.id, AggregatorV3Interface(address(0)));
        pool.setAssetPriceFeed(asset2.id, AggregatorV3Interface(address(0)));
        // Enable min-deposit limit so the oracle path is entered; without a limit
        // the guard returns early (correct post-H-1 behaviour).
        pool.setDepositLimits(1, type(uint256).max);

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DepositRestrictedAsAssetFeedNotSet.selector,
                asset1.id
            )
        );
        pool.transact(stx);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // _runDepositGuardRails — sanctioned-address screening
    // ─────────────────────────────────────────────────────────────────────────

    /// A DEPOSIT from a sanctioned caller reverts with SanctionedAddress. The
    /// sanction check is the first thing the deposit guard rails do, so it
    /// short-circuits before any token pull, limit, or feed logic.
    function test_revert_runDepositGuardRails_depositorSanctioned() public {
        address sanctionedDepositor = makeAddr("sanctionedDepositor");
        screener.setSanctioned(sanctionedDepositor, true);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IScreener.SanctionedAddress.selector,
                sanctionedDepositor
            )
        );
        vm.prank(sanctionedDepositor);
        pool.transact(stx);
    }

    /// A DEPOSIT from a clean caller still succeeds even when a *different*
    /// address is flagged, proving the screening check is caller-scoped and the
    /// dynamic mock does not leak into unrelated callers.
    function test_runDepositGuardRails_depositorNotSanctioned_succeeds()
        public
    {
        _registerAllFeeds();
        // Flag an unrelated actor — must not affect address(this).
        screener.setSanctioned(makeAddr("someOtherBadActor"), true);

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        pool.transact(stx); // must not revert
    }

    /// The sanction screening lives in the DEPOSIT-only branch, so a TRANSFER
    /// from a sanctioned caller must NOT be blocked by it.
    function test_runDepositGuardRails_sanctionSkippedForTransfer() public {
        _makePreDeposit();
        // Flag the caller only after the pre-deposit is in place.
        screener.setSanctioned(address(this), true);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_without_fee"
        );
        pool.transact(stx); // TRANSFER → deposit sanction check not triggered
    }

    /// The sanction screening lives in the DEPOSIT-only branch, so a WITHDRAW
    /// from a sanctioned caller must NOT be blocked by it.
    function test_runDepositGuardRails_sanctionSkippedForWithdraw() public {
        _makePreDeposit();
        screener.setSanctioned(address(this), true);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_100_weth_without_fee"
        );
        pool.transact(stx); // WITHDRAW → deposit sanction check not triggered
    }

    /// The zero-address screener kill-switch: once the owner disables screening
    /// via `setScreener(0)`, a previously-blocked sanctioned depositor can
    /// deposit. The first (sanctioned) attempt reverts before any state change,
    /// so the same transaction is reused for the successful attempt.
    /// Default test limits (min=0, max=∞, tvl=∞) mean no price feed is needed —
    /// the guard returns before the oracle path.
    function test_runDepositGuardRails_screenerDisabled_allowsDeposit() public {
        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        screener.setSanctioned(address(this), true);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IScreener.SanctionedAddress.selector,
                address(this)
            )
        );
        pool.transact(stx);

        // Owner disables screening entirely.
        pool.setScreener(IScreener(address(0)));

        pool.transact(stx); // must not revert
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setVerifier
    // ─────────────────────────────────────────────────────────────────────────

    function test_setVerifier_updatesAllProofPaths() public {
        MockVerifier newVerifier = new MockVerifier();

        vm.expectEmit(true, true, false, true);
        emit IPool.VerifierUpdated(address(verifier), address(newVerifier));

        pool.setVerifier(IVerifier(address(newVerifier)));

        assertEq(address(pool.verifier()), address(newVerifier));
        assertEq(
            address(pool.getCommitmentTreeVerifier()),
            address(newVerifier)
        );
    }

    function test_revert_setVerifier_zeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.InvalidVerifierAddress.selector,
                address(0)
            )
        );
        pool.setVerifier(IVerifier(address(0)));
    }

    function test_revert_setVerifier_eoa() public {
        address eoa = makeAddr("eoaVerifier");

        vm.expectRevert(
            abi.encodeWithSelector(IPool.InvalidVerifierAddress.selector, eoa)
        );
        pool.setVerifier(IVerifier(eoa));
    }

    function test_revert_setVerifier_notOwner() public {
        MockVerifier newVerifier = new MockVerifier();
        address notOwner = makeAddr("notOwner");

        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                notOwner
            )
        );
        pool.setVerifier(IVerifier(address(newVerifier)));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setScreener
    // ─────────────────────────────────────────────────────────────────────────

    /// A non-zero screener must hold code. An EOA would make every
    /// `isSanctioned` call revert and brick registrations and deposits.
    function test_revert_setScreener_eoa() public {
        address eoa = makeAddr("eoaScreener");

        vm.expectRevert(
            abi.encodeWithSelector(IPool.InvalidScreenerAddress.selector, eoa)
        );
        pool.setScreener(IScreener(eoa));

        assertEq(
            address(pool.screener()),
            address(screener),
            "screener must be unchanged after a rejected update"
        );
    }

    /// The zero address is exempt from the code check — it is the kill-switch
    /// that disables screening (see test_runDepositGuardRails_screenerDisabled_allowsDeposit).
    function test_setScreener_zeroAddressAllowedAsKillSwitch() public {
        vm.expectEmit(false, false, false, true);
        emit IPool.ScreenerUpdated(address(0));

        pool.setScreener(IScreener(address(0)));

        assertEq(address(pool.screener()), address(0));
    }

    function test_setScreener_acceptsContract() public {
        MockScreener newScreener = new MockScreener();

        vm.expectEmit(false, false, false, true);
        emit IPool.ScreenerUpdated(address(newScreener));

        pool.setScreener(IScreener(address(newScreener)));

        assertEq(address(pool.screener()), address(newScreener));
    }

    function test_revert_setScreener_notOwner() public {
        MockScreener newScreener = new MockScreener();
        address notOwner = makeAddr("notOwner");

        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                notOwner
            )
        );
        pool.setScreener(IScreener(address(newScreener)));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // renounceOwnership
    // ─────────────────────────────────────────────────────────────────────────

    /// Ownership can never be renounced: owner() configures assets, revokers,
    /// fees, limits and upgrades, so the Pool must always have one.
    function test_revert_renounceOwnership_owner() public {
        address ownerBefore = pool.owner();

        vm.prank(ownerBefore);
        vm.expectRevert(IPool.RenounceDisabled.selector);
        pool.renounceOwnership();

        assertEq(pool.owner(), ownerBefore, "owner must be unchanged");
    }

    /// The override keeps `onlyOwner`, which runs before the body, so a
    /// non-owner is rejected by the access check rather than RenounceDisabled.
    /// Either way ownership survives.
    function test_revert_renounceOwnership_notOwner() public {
        address ownerBefore = pool.owner();
        address notOwner = makeAddr("notOwner");

        vm.prank(notOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                notOwner
            )
        );
        pool.renounceOwnership();

        assertEq(pool.owner(), ownerBefore, "owner must be unchanged");
    }

    /// transferOwnership remains the supported way to move ownership.
    function test_transferOwnership_stillWorks() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(pool.owner());
        pool.transferOwnership(newOwner);

        assertEq(pool.owner(), newOwner);
    }

    /// @notice Fork test against the live Chainalysis sanctions oracle on
    /// Ethereum mainnet. Verifies that the real `Screener` flags a known
    /// sanctioned address and that wiring it into the Pool blocks a deposit.
    /// The sanction check is the first thing the deposit guard rails do, so it
    /// reverts before any token pull.
    /// @dev Run with a mainnet fork, e.g.
    ///      `forge test --fork-url $RPC_MAINNET --match-test test_fork_mainnetSanctionedAddressBlocksDeposit`
    function test_fork_mainnetSanctionedAddressBlocksDeposit() external {
        if (block.chainid != ETH_MAINNET) {
            vm.skip(true);
            return;
        }

        Screener realScreener = new Screener(MAINNET_SANCTIONS_LIST);

        // The live oracle flags the sanctioned address...
        assertTrue(
            realScreener.isSanctioned(SANCTIONED_ADDRESS),
            "expected address to be sanctioned on mainnet"
        );
        // ...but not an arbitrary fresh address.
        assertFalse(
            realScreener.isSanctioned(makeAddr("cleanAddress")),
            "did not expect random address to be sanctioned"
        );

        // Swap the mock for the real screener and confirm the deposit is blocked.
        pool.setScreener(IScreener(address(realScreener)));

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IScreener.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        vm.prank(SANCTIONED_ADDRESS);
        pool.transact(stx);
    }
}
