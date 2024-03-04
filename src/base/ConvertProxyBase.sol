// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IConvertProxy} from "../interfaces/IConvertProxy.sol";
import {IAssetManager} from "../interfaces/IAssetManager.sol";
import {Asset, AssetType} from "../libraries/DataTypes.sol";

/// NOTE: THIS SHOULD BE STATELESS - NO STORAGE VARS!!
abstract contract ConvertProxyBase is IConvertProxy {
    IAssetManager immutable _assetManager;

    constructor(address assetManager_) {
        _assetManager = IAssetManager(assetManager_);
    }

    function getAssetId(address assetAddress) public view returns (uint24) {
        return _assetManager.getAssetId(assetAddress);
    }

    function getAsset(uint24 assetId) public view returns (Asset memory) {
        return _assetManager.getAsset(assetId);
    }

    function getAsset(address assetAddress) public view returns (Asset memory) {
        return _assetManager.getAsset(assetAddress);
    }
}
