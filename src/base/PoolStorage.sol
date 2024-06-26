// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MerkleTree} from "../libraries/MerkleTree.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";
import {RevokerData} from "../libraries/ZTransaction.sol";

abstract contract PoolStorage {
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant ZERO_LEAF = uint256(keccak256("zkFi")) % FIELD_SIZE;

    address public verifier;
    address public adaptorHandler;
    address public sanctionScreener;

    MerkleTree internal _addressTree;
    mapping(uint256 => bool) internal _addressRegistered;

    /// Asset ids are are 3 bytes long - 1 byte for asset type and 2 bytes for asset uid
    mapping(AssetType => uint16) internal _assetCounts;
    mapping(address assetAddress => uint24 assetId) _assetIds;
    mapping(uint24 assetId => Asset asset) _assets;

    MerkleTree internal _commitmentTree;
    mapping(uint256 => bool) internal _markedNullifiers;

    mapping(address => bool) internal _adaptors;

    uint16 internal _revokerCount;
    mapping(uint256 => RevokerData) internal _revokers;
}
