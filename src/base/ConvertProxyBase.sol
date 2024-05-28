// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConvertProxy} from "../interfaces/IConvertProxy.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";

/// NOTE: THIS SHOULD BE STATELESS - NO STORAGE VARS!!
abstract contract ConvertProxyBase is IConvertProxy {
    IPool immutable _pool;

    constructor(address assetManager_) {
        _pool = IPool(assetManager_);
    }

    function getAssetId(address assetAddress) public view returns (uint24) {
        return _pool.getAsset(assetAddress).id;
    }

    function getAsset(uint24 assetId) public view returns (Asset memory) {
        return _pool.getAsset(assetId);
    }

    function getAsset(address assetAddress) public view returns (Asset memory) {
        return _pool.getAsset(assetAddress);
    }
}
