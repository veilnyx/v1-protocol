// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPool} from "../interfaces/IPool.sol";

enum AssetType {
    NULL,
    ERC20,
    ERC721,
    ERC1155
}

struct Asset {
    uint24 id;
    AssetType assetType;
    address assetAddress;
    bool isActive;
    uint8 precision;
    /// @dev Chainlink-compatible USD price feed for TVL calculation. address(0) = not set.
    AggregatorV3Interface usdPriceFeed;
    /// @dev Cached result of usdPriceFeed.decimals(), set when the feed is assigned.
    ///      Avoids a cold external call on every TVL/deposit-value query. 0 when feed is unset.
    uint8 feedDecimals;
}

/// @dev Parameters for a single asset to be registered via addAssets.
struct AssetInitParams {
    address assetAddress;
    uint8 precision;
    AggregatorV3Interface usdPriceFeed;
}

library AssetLogic {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error UnsupportedAssetType(uint24 assetId);

    function getAssetOrRevert(
        mapping(uint24 => Asset) storage assets,
        uint24 assetId
    ) public view returns (Asset memory asset) {
        asset = assets[assetId];
        if (!asset.isActive) {
            revert IPool.InactiveAsset(assetId);
        }
    }

    /// @custom:invariant Asset IDs are 3 bytes: 1 byte type + 2 bytes UID (asset counter)
    /// @custom:invariant Only active assets can be transferred/received
    function addAsset(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 assetCount,
        AssetType assetType,
        IERC20 assetAddress,
        uint8 precision,
        AggregatorV3Interface usdPriceFeed
    ) public returns (uint16) {
        if (_isAssetAdded(assetIds, address(assetAddress))) {
            revert IPool.DuplicateAsset(address(assetAddress));
        }

        if (address(assetAddress) == address(0)) {
            revert ZeroAddress();
        }

        assetCount += 1;

        // Asset ID: 1 byte type | 2 bytes asset counter
        uint24 newAssetId = (uint24(uint8(assetType)) << 16) |
            uint24(assetCount);

        assetIds[address(assetAddress)] = newAssetId;
        assets[newAssetId] = Asset({
            id: newAssetId,
            assetType: assetType,
            assetAddress: address(assetAddress),
            isActive: true,
            precision: precision,
            usdPriceFeed: usdPriceFeed,
            feedDecimals: address(usdPriceFeed) != address(0)
                ? usdPriceFeed.decimals()
                : 0
        });

        emit IPool.AssetAdded(address(assetAddress), newAssetId);
        return assetCount;
    }

    function addAssets(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 assetCount,
        AssetType assetType,
        AssetInitParams[] calldata initParams
    ) external returns (uint16) {
        for (uint256 i = 0; i < initParams.length; ) {
            assetCount = addAsset(
                assetIds,
                assets,
                assetCount,
                assetType,
                IERC20(initParams[i].assetAddress),
                initParams[i].precision,
                initParams[i].usdPriceFeed
            );
            unchecked {
                ++i;
            }
        }
        return assetCount;
    }

    function setAssetPriceFeed(
        mapping(uint24 => Asset) storage assets,
        uint24 assetId,
        AggregatorV3Interface feed
    ) external {
        Asset storage asset = assets[assetId];
        asset.usdPriceFeed = feed;
        asset.feedDecimals = address(feed) != address(0) ? feed.decimals() : 0;
    }

    function updateAsset(
        mapping(uint24 => Asset) storage assets,
        uint24 assetId,
        bool isActive
    ) external {
        if (assets[assetId].assetAddress == address(0)) {
            revert IPool.InactiveAsset(assetId);
        }
        assets[assetId].isActive = isActive;
    }

    function receiveAsset(
        mapping(uint24 => Asset) storage assets,
        address from,
        uint24 assetId,
        uint256 value
    ) external {
        Asset memory asset = getAssetOrRevert(assets, assetId);

        if (asset.assetType == AssetType.ERC20) {
            _receiveERC20(asset, from, address(this), value);
        } else {
            revert UnsupportedAssetType(assetId);
        }
    }

    function transferAsset(
        mapping(uint24 => Asset) storage assets,
        address to,
        uint24 assetId,
        uint256 value
    ) external {
        Asset memory asset = getAssetOrRevert(assets, assetId);

        if (asset.assetType == AssetType.ERC20) {
            _transferERC20(asset, to, value);
        } else {
            revert UnsupportedAssetType(assetId);
        }
    }

    function _isAssetAdded(
        mapping(address => uint24) storage assetIds,
        address assetAddress
    ) internal view returns (bool) {
        uint24 assetId = assetIds[assetAddress];
        return assetId != 0;
    }

    function _isAssetActive(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        address assetAddress
    ) internal view returns (bool) {
        uint24 assetId = assetIds[assetAddress];
        return assets[assetId].isActive;
    }

    function _receiveERC20(
        Asset memory asset,
        address from,
        address to,
        uint256 value
    ) internal {
        IERC20(asset.assetAddress).safeTransferFrom(from, to, value);
    }

    function _transferERC20(
        Asset memory asset,
        address to,
        uint256 value
    ) internal {
        IERC20(asset.assetAddress).safeTransfer(to, value);
    }
}
