// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AssetType} from "src/libraries/Asset.sol";

contract Config {
    uint256 public constant TREE_DEPTH = 32;
    mapping(uint256 => address) entryPoints;
    mapping(uint256 => AssetType) initialAssetTypes;
    mapping(uint256 => address[]) initialAssetAddresses;

    constructor() {
        //@todo set deployment configs
    }

    function treeDepth() external pure returns (uint256) {
        return TREE_DEPTH;
    }

    function entryPoint() external view returns (address) {
        return entryPoints[block.chainid];
    }

    function initalAssetType() external view returns (AssetType) {
        AssetType assetType = initialAssetTypes[block.chainid];
        return assetType;
    }

    function initalAssetAddresses() external view returns (address[] memory) {
        address[] memory addresses = initialAssetAddresses[block.chainid];
        return addresses;
    }
}
