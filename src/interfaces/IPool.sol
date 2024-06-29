// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZTransaction, ZTransactionType, RevokerData} from "../libraries/ZTransaction.sol";
import {AssetType, Asset} from "../libraries/Asset.sol";
import {PoolStorage} from "../base/PoolStorage.sol";

interface IPool {
    /////////////////////////////////////////
    //            EVENTS                   //
    ////////////////////////////////////////

    event RegisterAddress(
        address indexed sender,
        uint256 indexed addr,
        uint256 leafIndex,
        bytes publicKeys
    );
    event RevokerRegistered(
        uint256 indexed id,
        uint256[2] revokerPublicKey,
        uint256[2] encryptionPublicKey,
        bytes metadata
    );
    event RevokerStatusUpdated(uint256 indexed id, bool status);
    event NullifierMarked(uint256 indexed nullifier);

    event AssetAdded(address indexed assetAddress, uint24 assetId);

    // Commitments
    event Commitment(uint256 indexed leafIndex, uint256 indexed commitment);

    event Receipt(
        ZTransactionType indexed txType,
        uint16 indexed revokerId,
        uint32 lastLeafIndex,
        address target,
        uint24 feeAssetId,
        uint96 feeValue,
        address paymaster,
        bytes assetMemo, // sent memo in case of transfer or calc from pub assets
        bytes complianceMemo,
        bytes[] noteMemos
    );

    /////////////////////////////////////////
    //            ERRORS                   //
    ////////////////////////////////////////

    error AddressAlreadyRegistered(uint256 addr);
    error BadArguments();
    error InvalidProof();
    error UnknownCommitmentTreeRoot();
    error UnknownAddressTreeRoot();
    error DoubleSpend(uint256 markedNullifier);
    error UnsupportedAdaptor();
    error DuplicateAsset(address assetAddress);
    error UnsupportedAsset(uint24 assetId);
    error InvalidRevoker(uint256 id);
    error NoFeeToClaim(address paymaster, uint24 assetId);

    /////////////////////////////////////////
    //         ADMIN WRITE METHODS         //
    ////////////////////////////////////////

    function pause() external;

    function unpause() external;

    function addAssets(
        AssetType assetType,
        address[] memory assetAddresses
    ) external;

    function addAdaptorSupport(address proxyAddress, bool enable) external;

    function registerRevoker(
        uint256[2] calldata revokerKeys,
        uint256[2] calldata encryptionKeys,
        bytes calldata metadata
    ) external;

    function setRevokerStatus(uint256 index, bool status) external;

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        uint256 addr,
        bytes calldata publicKeys,
        bytes calldata signature
    ) external;

    function transact(ZTransaction calldata ztx) external;

    function withdrawPaymasterFee(uint24 assetId, address to) external;

    /////////////////////////////////////////
    //         READ METHODS                //
    ////////////////////////////////////////

    function verifyTransactionProof(
        ZTransaction calldata ztx
    ) external view returns (bool);

    function assetCount(AssetType assetType) external view returns (uint24);

    function isAssetSupported(
        address assetAddress
    ) external view returns (bool);

    function getAsset(uint24 assetId) external view returns (Asset memory);

    function getAsset(
        address assetAddress
    ) external view returns (Asset memory);

    function getPaymasterFee(
        uint24 assertId,
        address paymaster
    ) external view returns (uint256);

    function getRevokerData(
        uint256 revokerId
    ) external view returns (RevokerData memory);

    function isMarkedNullifier(uint256 nullifier) external view returns (bool);

    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory);

    function zeroes(uint8 level) external view returns (uint256);

    function getCommitmentTreeDepth() external view returns (uint256);

    function getAddressTreeDepth() external view returns (uint256);

    function getCommitmentTreeNextLeafIndex() external view returns (uint256);

    function getAddressTreeNextLeafIndex() external view returns (uint256);

    function getCommitmentTreeLastRoot() external view returns (uint256);

    function getAddressTreeLastRoot() external view returns (uint256);

    function getCommitmentTreeCurrentRootIndex()
        external
        view
        returns (uint256);

    function getAddressTreeCurrentRootIndex() external view returns (uint256);

    function isKnownCommitmentTreeRoot(
        uint256 root
    ) external view returns (bool);

    function isKnownAddressTreeRoot(uint256 root) external view returns (bool);
}
