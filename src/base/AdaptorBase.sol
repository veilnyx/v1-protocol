// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IAdaptor} from "../interfaces/IAdaptor.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";

/// NOTE: THIS SHOULD BE STATELESS - NO STORAGE VARS!!
abstract contract AdaptorBase is IAdaptor {
    error InactiveAsset(uint24 assetId);
    error ZeroValue();
    error InvalidAction();
    error UnsupportedAsset(uint24 assetId);
    error InsufficientBalance();

    IPool immutable _pool;

    constructor(address pool_) {
        _pool = IPool(pool_);
    }

    function getAssetId(address assetAddress) public view returns (uint24) {
        Asset memory asset = _pool.getAsset(assetAddress);
        if (!asset.isActive) {
            revert InactiveAsset(asset.id);
        }
        return asset.id;
    }

    function getAsset(uint24 assetId) public view returns (Asset memory) {
        Asset memory asset = _pool.getAsset(assetId);
        if (!asset.isActive) {
            revert InactiveAsset(asset.id);
        }
        return asset;
    }

    function getAsset(address assetAddress) public view returns (Asset memory) {
        Asset memory asset = _pool.getAsset(assetAddress);
        if (!asset.isActive) {
            revert InactiveAsset(asset.id);
        }
        return asset;
    }
}
