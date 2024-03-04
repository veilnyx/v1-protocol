// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWToken} from "../interfaces/IWToken.sol";
import {IAssetManager} from "../interfaces/IAssetManager.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Asset, AssetType} from "../libraries/DataTypes.sol";

library AssetLogic {
    using SafeERC20 for IERC20;

    event AssetListed(address indexed assetAddress, uint24 assetId);

    function isAssetSupported(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        address assetAddress
    ) public view returns (bool) {
        uint24 assetId = assetIds[assetAddress];
        return assets[assetId].isSupported;
    }

    function getAssetOrRevert(
        mapping(uint24 => Asset) storage assets,
        uint24 assetId
    ) public view returns (Asset memory asset) {
        asset = assets[assetId];
        if (!asset.isSupported) {
            revert IAssetManager.UnsupportedAsset(assetId);
        }
    }

    function addAsset(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 counter,
        AssetType assetType,
        address assetAddress
    ) public returns (uint16) {
        if (isAssetSupported(assetIds, assets, assetAddress)) {
            revert IAssetManager.DuplicateAsset(assetAddress);
        }

        if (assetType != AssetType.ERC20) {
            revert IAssetManager.UnsupportedAssetType(assetType);
        }

        // Uid of added asset
        uint16 newCount = counter + 1;

        // Concat asset type and uid to get asset id
        uint24 newAssetId = uint24(
            bytes3(bytes.concat(bytes1(uint8(assetType)), bytes2(newCount)))
        );

        assetIds[assetAddress] = newAssetId;
        assets[newAssetId] = Asset({
            assetType: assetType,
            assetAddress: assetAddress,
            isSupported: true
        });

        emit AssetListed(assetAddress, newAssetId);

        return newCount;
    }

    function addAssets(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 counter,
        AssetType[] calldata assetTypes,
        address[] calldata assetAddresses
    ) external returns (uint16) {
        if (assetTypes.length != assetAddresses.length) {
            revert IAssetManager.BadArguments();
        }

        for (uint256 i = 0; i < assetTypes.length; ) {
            counter = addAsset(
                assetIds,
                assets,
                counter,
                assetTypes[i],
                assetAddresses[i]
            );

            unchecked {
                ++i;
            }
        }
        return counter;
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
            revert IAssetManager.UnsupportedAssetType(asset.assetType);
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
            revert IAssetManager.UnsupportedAssetType(asset.assetType);
        }
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
