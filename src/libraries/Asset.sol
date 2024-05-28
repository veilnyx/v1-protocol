// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";

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
    bool isSupported;
}

library AssetLogic {
    using SafeERC20 for IERC20;

    function getAssetOrRevert(
        mapping(uint24 => Asset) storage assets,
        uint24 assetId
    ) public view returns (Asset memory asset) {
        asset = assets[assetId];
        if (!asset.isSupported) {
            revert IPool.UnsupportedAsset(assetId);
        }
    }

    function addAsset(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 counter,
        AssetType assetType,
        address assetAddress
    ) public returns (uint16) {
        if (_isAssetSupported(assetIds, assets, assetAddress)) {
            revert IPool.DuplicateAsset(assetAddress);
        }

        // Uid of added asset
        uint16 uid = counter + 1;

        // Concat asset type and uid to get asset id
        uint24 newAssetId = uint24(
            bytes3(bytes.concat(bytes1(uint8(assetType)), bytes2(uid)))
        );

        assetIds[assetAddress] = newAssetId;
        assets[newAssetId] = Asset({
            id: newAssetId,
            assetType: assetType,
            assetAddress: assetAddress,
            isSupported: true
        });

        emit IPool.AssetAdded(assetAddress, newAssetId);
        return uid;
    }

    function addAssets(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 counter,
        AssetType assetType,
        address[] calldata assetAddresses
    ) external returns (uint16) {
        for (uint8 i = 0; i < assetAddresses.length; ) {
            counter = addAsset(
                assetIds,
                assets,
                counter,
                assetType,
                assetAddresses[i]
            );

            unchecked {
                ++i;
            }
        }
        return counter;
    }

    function updateAsset(
        mapping(uint24 => Asset) storage assets,
        uint24 assetId,
        bool isSupported
    ) external {
        Asset storage asset = assets[assetId];
        asset.isSupported = isSupported;
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
            revert IPool.UnsupportedAsset(assetId);
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
            revert IPool.UnsupportedAsset(assetId);
        }
    }

    function _isAssetSupported(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        address assetAddress
    ) internal view returns (bool) {
        uint24 assetId = assetIds[assetAddress];
        return assets[assetId].isSupported;
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
