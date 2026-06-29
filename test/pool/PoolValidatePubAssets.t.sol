// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

/// @dev Unit tests for Pool._validateNoDuplicatePubAssets (exposed via MockPool).
///      The function extracts the 3-byte assetId from each uint248 pubAsset element,
///      insertion-sorts the ids, then reverts with DuplicatePubAssetId if any two
///      adjacent ids are equal.
contract PoolValidatePubAssetsTest is PoolTest {
    function setUp() public {
        _setUp();
    }

    // pubAsset encoding: bytes3(assetId) ++ bytes28(value) packed as uint248
    function _enc(
        uint24 assetId,
        uint224 value
    ) internal pure returns (uint248) {
        return uint248(bytes31(bytes.concat(bytes3(assetId), bytes28(value))));
    }

    function _stx(
        uint248[] memory pubAssets
    ) internal pure returns (ShieldedTransaction memory stx) {
        stx.pubAssets = pubAssets;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // No revert: short-circuit paths (n ≤ 1)
    // ─────────────────────────────────────────────────────────────────────────

    function test_emptyPubAssets_noRevert() public view {
        pool.mock_validateNoDuplicatePubAssets(_stx(new uint248[](0)));
    }

    function test_singlePubAsset_noRevert() public view {
        uint248[] memory pubAssets = new uint248[](1);
        pubAssets[0] = _enc(1, 1e18);
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // No revert: 2+ elements, all distinct asset IDs
    // ─────────────────────────────────────────────────────────────────────────

    function test_twoDifferentAssets_noRevert() public view {
        uint248[] memory pubAssets = new uint248[](2);
        pubAssets[0] = _enc(1, 100);
        pubAssets[1] = _enc(2, 200);
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    function test_fourUniqueAssetsOutOfOrder_noRevert() public view {
        // Deliberately unsorted to exercise the insertion-sort path
        uint248[] memory pubAssets = new uint248[](4);
        pubAssets[0] = _enc(4, 400);
        pubAssets[1] = _enc(2, 200);
        pubAssets[2] = _enc(3, 300);
        pubAssets[3] = _enc(1, 100);
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Revert: duplicate detected
    // ─────────────────────────────────────────────────────────────────────────

    function test_revert_twoDuplicateAssets() public {
        uint248[] memory pubAssets = new uint248[](2);
        pubAssets[0] = _enc(5, 100);
        pubAssets[1] = _enc(5, 200);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DuplicatePubAssetId.selector,
                uint24(5)
            )
        );
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    function test_revert_duplicateFirstTwoOfThree() public {
        uint248[] memory pubAssets = new uint248[](3);
        pubAssets[0] = _enc(1, 100);
        pubAssets[1] = _enc(1, 200);
        pubAssets[2] = _enc(3, 300);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DuplicatePubAssetId.selector,
                uint24(1)
            )
        );
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    function test_revert_duplicateLastTwoOfThree() public {
        uint248[] memory pubAssets = new uint248[](3);
        pubAssets[0] = _enc(1, 100);
        pubAssets[1] = _enc(3, 200);
        pubAssets[2] = _enc(3, 300);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DuplicatePubAssetId.selector,
                uint24(3)
            )
        );
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    function test_revert_nonAdjacentDuplicate() public {
        // [id=3, id=1, id=3] → sorted: [1, 3, 3] → duplicate on ids[1]==ids[2]
        uint248[] memory pubAssets = new uint248[](3);
        pubAssets[0] = _enc(3, 100);
        pubAssets[1] = _enc(1, 200);
        pubAssets[2] = _enc(3, 300);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DuplicatePubAssetId.selector,
                uint24(3)
            )
        );
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    function test_revert_allThreeSameId() public {
        uint248[] memory pubAssets = new uint248[](3);
        pubAssets[0] = _enc(7, 100);
        pubAssets[1] = _enc(7, 200);
        pubAssets[2] = _enc(7, 300);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DuplicatePubAssetId.selector,
                uint24(7)
            )
        );
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }

    function test_revert_duplicateZeroValue() public {
        // Value difference does not exempt a duplicate; only assetId matters
        uint248[] memory pubAssets = new uint248[](2);
        pubAssets[0] = _enc(2, 0);
        pubAssets[1] = _enc(2, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.DuplicatePubAssetId.selector,
                uint24(2)
            )
        );
        pool.mock_validateNoDuplicatePubAssets(_stx(pubAssets));
    }
}
