// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ZTransaction} from "../libraries/ZTransaction.sol";
import {AssetType, Asset} from "../libraries/Asset.sol";

interface IPool {
    /////////////////////////////////////////
    //            EVENTS                   //
    ////////////////////////////////////////

    event Announcement(
        uint256 indexed leafIndex,
        uint256 indexed commitment,
        bytes outMemo
    );
    event RegisterComplianceKeys(uint256 indexed id, uint256[4] keys);
    event InputNoteMemos(bytes inMemos);
    event ComplianceMemo(bytes complianceMemo);
    event NullifierMarked(uint256 indexed nullifier);
    event AssetAdded(address indexed assetAddress, uint24 assetId);

    /////////////////////////////////////////
    //            ERRORS                   //
    ////////////////////////////////////////

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

    function transact(ZTransaction memory ztx) external;

    function addAssets(
        AssetType assetType,
        address[] memory assetAddresses
    ) external;

    function setConvertProxy(address proxyAddress, bool enable) external;

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

    function isMarkedNullifier(uint256 nullifier) external view returns (bool);

    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory);

    function zeroes(uint256 level) external view returns (uint256);

    function getLastRoot() external view returns (uint256);

    function getCurrentRootIndex() external view returns (uint256);

    function getLastSubtrees(uint256 level) external view returns (uint256);

    function isKnownRoot(uint256 root) external view returns (bool);

    function getRevokerPublicKey() external view returns (uint256, uint256);

    function getEncryptionPublicKey() external view returns (uint256, uint256);
}
