// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Asset} from "src/libraries/AssetLogic.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

/// @dev Integration tests for the TVL guard in Pool.transact().
///      PoolTest sets up three ERC20 assets: asset1 (18-dec), asset2 (6-dec), asset3 (18-dec).
///
///      deposit_pre_tx deposits 10000 asset1 (10 000e18) + 10000 asset2 (10 000e6).
///      With WETH feed at $2000 (8-dec) and USDC feed at $1 (8-dec):
///        WETH contribution: 10000e18 * 2000e8 / 10^8 = 20_000_000e18
///        USDC contribution: 10000e6 * 1e8 * 10^4     =     10_000e18
///        tokenReent balance:  0  →  0
///        Total TVL = 20_010_000e18
///
///      Tests 14/15 run without a prior _makePreDeposit() so the deposit fixture
///      can be used fresh.  Tests 16/17 call _makePreDeposit() inside the test
///      body to get the tree into the state expected by transfer/withdraw fixtures.
contract TvlGuardTest is PoolTest {
    MockAggregatorV3 internal mockFeed1; // asset1 (token1, 18-dec) at $2000
    MockAggregatorV3 internal mockFeed2; // asset2 (token2,  6-dec) at $1
    MockAggregatorV3 internal mockFeed3; // asset3 (tokenReent, 18-dec) at $1

    Asset public asset3;

    /// @dev TVL produced by deposit_pre_tx with the feeds above (6-dec USD).
    uint256 internal constant DEPOSIT_TVL = 20_010_000e6;

    function setUp() public {
        _setUp();

        asset3 = pool.getAsset(address(tokenReent));

        mockFeed1 = new MockAggregatorV3(int256(2000e8), 8);
        mockFeed2 = new MockAggregatorV3(int256(1e8), 8);
        mockFeed3 = new MockAggregatorV3(int256(1e8), 8);

        // Register feeds. tvlLimitUsd stays 0 (disabled) so _makePreDeposit() in
        // individual tests can execute freely.
        pool.setAssetPriceFeed(
            asset1.id,
            AggregatorV3Interface(address(mockFeed1))
        );
        pool.setAssetPriceFeed(
            asset2.id,
            AggregatorV3Interface(address(mockFeed2))
        );
        pool.setAssetPriceFeed(
            asset3.id,
            AggregatorV3Interface(address(mockFeed3))
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 14. DEPOSIT succeeds when resulting TVL is below the limit
    // ─────────────────────────────────────────────────────────────────────────

    function test_deposit_belowTvlLimit() public {
        pool.setTvlLimitUsd(500_000_000e6); // $500 M — well above $20 M deposit

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        pool.transact(stx); // TVL after ≈ $20 M < $500 M → success
    }

    function test_deposit_testnetWeth_belowTvlLimit() public {
        if (block.chainid != 11155111 && block.chainid != 1) {
            vm.skip(true);
        }

        pool.setTvlLimitUsd(500_000_000e6); // $500 M — well above $20 M deposit

        // increasing pool's TVL
        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        pool.transact(stx); // TVL after ≈ $20 M < $500 M → success

        // depositing testnet WETH (this should invoke Chainlink feed on forked chains)
        address testnet_weth = config.wToken();
        vm.deal(address(this), 2 ether);
        IWToken(testnet_weth).deposit{value: 2 ether}();
        IWToken(testnet_weth).approve(address(pool), 2 ether);
        ShieldedTransaction memory stx_testnet_weth = _loadShieldedTransaction(
            "deposit_2_testnet_weth"
        );
        pool.transact(stx_testnet_weth);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 15. DEPOSIT reverts when resulting TVL exceeds the limit
    // ─────────────────────────────────────────────────────────────────────────

    function test_revert_deposit_exceedsTvlLimit() public {
        pool.setTvlLimitUsd(1e6); // $1 limit — deposit would push TVL to $20 M

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000e6);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.TvlLimitExceeded.selector,
                DEPOSIT_TVL,
                uint256(1e6)
            )
        );
        pool.transact(stx);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 16. TRANSFER bypasses the TVL guard regardless of limit
    // ─────────────────────────────────────────────────────────────────────────

    function test_transfer_ignoresTvlLimit() public {
        // Pre-deposit so the commitment tree is in the state expected by the
        // transfer fixture. tvlLimitUsd is 0 here → deposit guard is skipped.
        _makePreDeposit();

        // Now arm the limit at $1 — any deposit would fail, but TRANSFER should
        // not be subject to the TVL cap.
        pool.setTvlLimitUsd(1e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "transfer_20_weth_without_fee"
        );
        pool.transact(stx); // TRANSFER type → TVL guard not triggered → success
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 17. WITHDRAW bypasses the TVL guard regardless of limit
    // ─────────────────────────────────────────────────────────────────────────

    function test_withdraw_ignoresTvlLimit() public {
        // Pre-deposit so the pool holds tokens and the tree is initialised.
        _makePreDeposit();

        pool.setTvlLimitUsd(1e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "withdraw_100_weth_without_fee"
        );
        pool.transact(stx); // WITHDRAW type → TVL guard not triggered → success
    }
}
