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
    bool isActive;
}

library AssetLogic {
    using SafeERC20 for IERC20;

    error ZeroAddress();

    function getAssetOrRevert(
        mapping(uint24 => Asset) storage assets,
        uint24 assetId
    ) public view returns (Asset memory asset) {
        asset = assets[assetId];
        if (!asset.isActive) {
            revert IPool.InactiveAsset(assetId);
        }
    }

    function addAsset(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 counter,
        AssetType assetType,
        address assetAddress
    ) public returns (uint16) {
        if (_isAssetAdded(assetIds, assetAddress)) {
            revert IPool.DuplicateAsset(assetAddress);
        }

        if (assetAddress == address(0)) {
            revert ZeroAddress();
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
            isActive: true
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
        bool isActive
    ) external {
        Asset storage asset = assets[assetId];
        asset.isActive = isActive;
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
            revert IPool.InactiveAsset(assetId);
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
            revert IPool.InactiveAsset(assetId);
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
