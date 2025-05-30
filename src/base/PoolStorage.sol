// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MerkleTree} from "../libraries/MerkleTree.sol";
import {QueuedMerkleTree} from "../libraries/QueuedMerkleTree.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";
import {RevokerData} from "../libraries/ShieldedTransaction.sol";

struct ProtocolFee {
    uint16 bps; // since max deposit fee is 100% of the deposit amt, we can use uint16
    bool isActive;
}

abstract contract PoolStorage {
    address public verifier;
    address public adaptorHandler;
    address public hasher;
    address public screener;

    MerkleTree internal _addressTree;
    QueuedMerkleTree internal _commitmentTree;

    mapping(uint256 => bool) internal _rootAddresses;
    mapping(address => uint256) internal _publicAddresses;

    /// Asset ids are are 3 bytes long - 1 byte for asset type and 2 bytes for asset uid
    mapping(AssetType => uint16) internal _assetCounts;
    mapping(address assetAddress => uint24 assetId) _assetIds;
    mapping(uint24 assetId => Asset asset) _assets;

    mapping(uint256 nullifier => uint32 markLeafIndex)
        internal _markedNullifiers;

    mapping(address => bool) internal _adaptors;

    uint16 internal _revokerCount;
    mapping(uint256 => bool) internal _revokerPublicKeys;
    mapping(uint256 => RevokerData) internal _revokers;

    /// todo To be removed after the migration to the new fee structure when deploying a fresh pool with state reset
    uint256 public withdrawFeeBps; // 1 bip = 1% / 100
    mapping(uint24 => uint256) internal _withdrawFees;
    mapping(address paymaster => mapping(uint24 assetId => uint256 feeAmount))
        internal _paymasterFees;

    address public mempool;
    address public verificationTrackerService;
    mapping(uint24 => uint256) internal _proofSubAndMempoolExitFee;

    ProtocolFee public depositProtocolFee;
    ProtocolFee public withdrawProtocolFee;
    ProtocolFee public transferProtocolFee;
    ProtocolFee public adaptorProtocolFee;
}
