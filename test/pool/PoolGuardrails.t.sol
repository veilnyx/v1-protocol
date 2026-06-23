// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Asset, AssetType} from "src/libraries/AssetLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";
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
        emit IPool.AssetUsdPriceFeedSet(asset1.id, address(mockFeed1));

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
                IPool.TvlPriceInvalid.selector,
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
                IPool.TvlPriceInvalid.selector,
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
    // setMinDepositUsd / setMaxDepositUsd
    // ─────────────────────────────────────────────────────────────────────────

    function test_setMinDepositUsd() public {
        uint256 limit = 5e6; // $5
        vm.expectEmit(false, false, false, true);
        emit IPool.MinDepositUpdated(limit);

        pool.setMinDepositUsd(limit);
        assertEq(pool.minDepositUsd(), limit);
    }

    function test_revert_setMinDepositUsd_notOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert();
        pool.setMinDepositUsd(5e6);
    }

    function test_setMaxDepositUsd() public {
        uint256 limit = 50e6; // $50
        vm.expectEmit(false, false, false, true);
        emit IPool.MaxDepositUpdated(limit);

        pool.setMaxDepositUsd(limit);
        assertEq(pool.maxDepositUsd(), limit);
    }

    function test_revert_setMaxDepositUsd_notOwner() public {
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert();
        pool.setMaxDepositUsd(50e6);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // whenDepositWithinLimits modifier
    // ─────────────────────────────────────────────────────────────────────────

    /// deposit_pre_tx deposits ~$20 010 000 (with mockFeed1 at $2000, mockFeed2 at $1).
    /// Setting minDepositUsd above that value must trigger DepositBelowMinimum.
    function test_revert_whenDepositWithinLimits_belowMinimum() public {
        _registerAllFeeds();
        pool.setMinDepositUsd(25_000_000e6); // $25 M > ~$20 M deposit

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
        pool.setMaxDepositUsd(1_000e6); // $1 000 < ~$20 M deposit

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
        pool.setMinDepositUsd(1e6); // $1 — below ~$20 M
        pool.setMaxDepositUsd(25_000_000e6); // $25 M — above ~$20 M

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

        // Arm tight limits — any deposit would fail.
        pool.setMinDepositUsd(1_000_000_000e6); // $1 B minimum
        pool.setMaxDepositUsd(1e6); // $1 maximum

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_without_fee"
        );
        pool.transact(stx); // TRANSFER → deposit guard not triggered → success
    }

    /// WITHDRAW transactions must bypass the deposit limit check entirely.
    function test_whenDepositWithinLimits_withdrawIgnoresLimits() public {
        _makePreDeposit();

        pool.setMinDepositUsd(1_000_000_000e6);
        pool.setMaxDepositUsd(1e6);

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
        pool.setMinDepositUsd(1);

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
}
