// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZTransaction, ZTransactionType, ComplianceKeys} from "../libraries/ZTransaction.sol";
import {AssetType, Asset} from "../libraries/Asset.sol";
import {PoolStorage} from "src/base/PoolStorage.sol";

interface IPool {
    /////////////////////////////////////////
    //            EVENTS                   //
    ////////////////////////////////////////

    event Announcement(
        uint256 indexed leafIndex,
        uint256 indexed commitment,
        bytes outMemo
    );
    event RegisterAddress(
        address indexed sender,
        uint256 indexed addr,
        uint256 leafIndex,
        bytes publicKeys
    );
    event RegisterComplianceKeys(
        uint256 indexed id,
        uint256[2] revokerPublicKey,
        uint256[2] encryptionPublicKey
    );
    event InputNoteMemos(bytes inMemos);
    event ComplianceMemo(bytes complianceMemo);
    event NullifierMarked(uint256 indexed nullifier);
    event AssetAdded(address indexed assetAddress, uint24 assetId);

    // how do i know its mine & whether im sender or receiver
    event ZTransactionLog(
        ZTransactionType indexed txType,
        uint256 revokerId,
        bytes historyMemo,
        bytes[] memos,
        uint256 endLeafIndex
    );

    /////////////////////////////////////////
    //            ERRORS                   //
    ////////////////////////////////////////

    error AddressAlreadyRegistered(uint256 addr);
    error BadArguments();
    error InvalidProof();
    error UnexpectedFee();
    error UnknownMerkleRoot();
    error DoubleSpend(uint256 markedNullifier);
    error UnsupportedProxy();
    error DuplicateAsset(address assetAddress);
    error UnsupportedAsset(uint24 assetId);

    /////////////////////////////////////////
    //         WRITE METHODS               //
    ////////////////////////////////////////

    function register(
        uint256 addr,
        bytes calldata publicKeys,
        bytes calldata signature
    ) external;

    function transact(ZTransaction memory ztx) external;

    function addAssets(
        AssetType assetType,
        address[] memory assetAddresses
    ) external;

    function addAdaptorSupport(address proxyAddress, bool enable) external;

    function registerComplianceKeys(
        uint256[2] calldata revokerKeys,
        uint256[2] calldata encryptionKeys
    ) external;

    function changeComplianceKeyStatus(uint256 index, bool status) external;

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

    function getComplianceKey(
        uint256 index
    ) external view returns (ComplianceKeys memory);

    function isMarkedNullifier(uint256 nullifier) external view returns (bool);

    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory);

    function zeroes(uint256 level) external view returns (uint256);

    function getCommitmentTreeDepth() external view returns (uint256);

    function getCommitmentTreeNextLeafIndex() external view returns (uint256);

    function getCommitmentTreeLastRoot() external view returns (uint256);

    function getCommitmentTreeCurrentRootIndex()
        external
        view
        returns (uint256);

    function getAddressTreeDepth() external view returns (uint256);

    function isKnownRoot(uint256 root) external view returns (bool);

    function getRevokerPublicKey() external view returns (uint256, uint256);

    function getEncryptionPublicKey() external view returns (uint256, uint256);
}
