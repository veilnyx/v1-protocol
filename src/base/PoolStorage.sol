// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MerkleTree} from "../libraries/MerkleTree.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";

abstract contract PoolStorage {
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    uint256 public constant ZERO_LEAF = uint256(keccak256("zkFi")) % FIELD_SIZE;

    address public entryPoint;
    address public verifier;
    address public convertor;

    mapping(AssetType => uint16) internal _assetCounts;

    /// Asset ids are are 3 bytes long - 1 byte for asset type and 2 bytes for asset uid
    mapping(uint24 assetId => Asset asset) _assets;

    MerkleTree internal _tree;

    mapping(address assetAddress => uint24 assetId) _assetIds;

    mapping(uint256 => bool) internal _markedNullifiers;

    mapping(address => bool) internal _convertProxies;
}
