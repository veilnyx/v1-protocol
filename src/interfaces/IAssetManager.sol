// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Asset, AssetType} from "../libraries/DataTypes.sol";

interface IAssetManager {
    error BadArguments();
    error DuplicateAsset(address assetAddress);
    error UnsupportedAsset(uint24 assetId);
    error UnsupportedAssetType(AssetType assetType);

    event AssetListed(address indexed assetAddress, uint24 assetId);

    function isAssetSupported(address assetAddress) external view returns (bool);

    function getAssetId(address assetAddress) external view returns (uint24);

    function getAsset(uint24 assetId) external view returns (Asset memory);

    function getAsset(address assetAddress) external view returns (Asset memory);

    // function addAsset(AssetType assetType, address assetAddress) external;
}
