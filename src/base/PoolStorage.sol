// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MerkleTree} from "../libraries/MerkleTreeLogic.sol";
import {Asset, AssetType} from "../libraries/DataTypes.sol";

contract PoolStorage {
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant ZERO_LEAF = uint256(keccak256("zkFi")) % FIELD_SIZE;
    uint8 public constant ROOT_HISTORY_SIZE = 100;

    address public verifier;
    address public convertor;

    MerkleTree internal _tree;

    uint16 internal _counter;

    /// @dev Asset ids are are 3 bytes long - 1 byte for asset type and 2 bytes for asset uid
    mapping(uint24 assetId => Asset asset) _assets;

    mapping(address assetAddress => uint24 assetId) _assetIds;

    mapping(uint256 => bool) internal _markedNullifiers;

    mapping(address => bool) internal _supportedProxies;
}
