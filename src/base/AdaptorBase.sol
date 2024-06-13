// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAdaptor} from "../interfaces/IAdaptor.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";

/// NOTE: THIS SHOULD BE STATELESS - NO STORAGE VARS!!
abstract contract AdaptorBase is IAdaptor {
    IPool immutable _pool;

    constructor(address pool_) {
        _pool = IPool(pool_);
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
