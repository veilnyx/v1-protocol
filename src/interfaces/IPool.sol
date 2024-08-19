// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ShieldedTransaction, ShieldedTransactionType, RevokerData} from "../libraries/ShieldedTransaction.sol";
import {ShieldedAddressRegistrationData} from "../libraries/ShieldedAddress.sol";
import {TreeUpdateData} from "../libraries/QueuedMerkleTree.sol";
import {AssetType, Asset} from "../libraries/Asset.sol";
import {PoolStorage} from "../base/PoolStorage.sol";

interface IPool {
    /////////////////////////////////////////
    //            EVENTS                   //
    ////////////////////////////////////////

    event RegisterAddress(
        address indexed publicAddress,
        uint256 indexed rootAddress,
        uint32 leafIndex,
        bytes shieldedAddress
    );
    event RevokerRegistered(
        uint256 indexed id,
        uint256[2] revokerPublicKey,
        uint256[2] encryptionPublicKey,
        bytes metadata
    );
    event RevokerStatusUpdated(uint256 indexed id, bool status);
    event NullifierMarked(uint256 indexed nullifier, uint32 markLeafIndex);

    event AssetAdded(address indexed assetAddress, uint24 assetId);

    // Commitments
    event Commitment(uint256 indexed leafIndex, uint256 indexed commitment);

    event Receipt(
        ShieldedTransactionType indexed txType,
        uint16 indexed revokerId,
        uint32 lastLeafIndex,
        address target,
        uint24 feeAssetId,
        uint96 feeValue,
        address paymaster,
        bytes keysMemo,
        bytes assetsMemo, // sent memo in case of transfer or calc from pub assets
        bytes notesMemo,
        bytes refundMemo
    );

    /////////////////////////////////////////
    //            ERRORS                   //
    ////////////////////////////////////////

    error RootAddressAlreadyRegistered(uint256 addr);
    error PublicAddressAlreadyRegistered(address addr);
    error BadArguments();
    error InvalidAddressProof();
    error InvalidSubtreeUpdateProof();
    error InvalidTransactionProof();
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

    /// @notice Pauses the contract. While paused, no transactions can be executed.
    /// @notice Can only be called by the owner.
    function pause() external;

    /// @notice Unpauses the contract.
    /// @notice Can only be called by the owner.
    function unpause() external;

    /// @notice Adds support for new assets in the protocol.
    /// @notice Can only be called by the owner.
    /// @param assetType The type of the asset to be added.
    /// @param assetAddresses The addresses of the assets.
    function addAssets(
        AssetType assetType,
        address[] memory assetAddresses
    ) external;

    /// @notice Adds support for an external adaptor to a DeFi protocol.
    /// @notice Can only be called by the owner.
    /// @param adaptorAddress The address of the adaptor contract.
    /// @param enable Whether to enable or disable the adaptor.
    function addAdaptorSupport(address adaptorAddress, bool enable) external;

    /// @notice Registers a new revoker. Revokers are responsible for deanonymizing transactions along with a network of Guardians.
    /// @notice Can only be called by the owner.
    /// @param revokerPublicKey The public key of the revoker. Public key represents a point of the elliptic curve, hence it is a pair of two 256-bit integers.
    /// @param encryptionPublicKey The guardian network's public key used for encrypting the transactions.
    /// @param revokerMetadata Metadata for the revoker (e.g. name, description).
    function registerRevoker(
        uint256[2] calldata revokerPublicKey,
        uint256[2] calldata encryptionPublicKey,
        bytes calldata revokerMetadata
    ) external;

    /// @notice A function to withdraw the collected withdrawal fee for an asset by the protocol.
    /// @notice Can only be called by the owner.
    /// @param assetId The id of the asset for which the paymaster wants to claim the fee.
    /// @param to The address to which the fee will be transferred.
    function withdrawProtocolFee(uint24 assetId, address to) external;

    /// @notice Updates the status of a revoker.
    /// @notice Can only be called by the owner.
    function setRevokerStatus(uint256 index, bool status) external;

    /// @notice Sets the address of the address screener/sactionion contract.
    /// @notice Can only be called by the owner.
    function setScreener(address screener) external;

    /// @notice Sets the no. of bips (basis points: 1/10000) fee that is charged for withdrawing assets from the pool.
    /// @notice Can only be called by the owner.
    function setWithdrawFeeBips(uint256 feeBips) external;

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    /// @notice Registers a new user using their address hash in the protocol.
    /// @notice Can only be called when the contract is not paused.
    /// @param addressRegData The user's shielded address data including shieled address and proof.
    function registerAddress(
        ShieldedAddressRegistrationData calldata addressRegData
    ) external;

    /// @notice Updates the commitment tree with a queue of leaves. It uses zk proof under the hood to prove the `newRoot` and `newSubtrees` are valid.
    /// @param updatedCommitmentTreeInputs The inputs needed by the zk verifier to verify the authenticity of the queued merkle tree update.
    function updateCommitmentTree(
        TreeUpdateData memory updatedCommitmentTreeInputs
    ) external;

    /// @notice Validates and executes a stx.
    /// @notice Can only be called when the contract is not paused.
    /// @param stx The stx to be executed.
    function transact(ShieldedTransaction calldata stx) external;

    /// @notice A function to call by a paymaster contract to claim the asset wise fees collected for the ERC-4337 transactions they catered to.
    /// @notice Can only be called when the contract is not paused.
    /// @param assetId The id of the asset for which the paymaster wants to claim the fee.
    /// @param to The address to which the fee will be transferred.
    function withdrawPaymasterFee(uint24 assetId, address to) external;

    /////////////////////////////////////////
    //         READ METHODS                //
    ////////////////////////////////////////

    /// @notice Verifies the proof of a stx.
    /// @param stx The stx to be verified.
    function verifyTransactionProof(
        ShieldedTransaction calldata stx
    ) external view returns (bool);

    /// @notice Returns the no. of assets supported by asset type.
    /// @param assetType The type of the asset. Ref. enum Asset::AssetType
    function assetCount(AssetType assetType) external view returns (uint24);

    /// @notice Returns if an asset is supported.
    /// @param assetAddress The address of the asset to check.
    function isAssetSupported(
        address assetAddress
    ) external view returns (bool);

    /// @notice Returns the data of an asset.
    /// @param assetId The id of the asset.
    function getAsset(uint24 assetId) external view returns (Asset memory);

    /// @notice Returns the data of an asset.
    /// @param assetAddress The address of the asset.
    function getAsset(
        address assetAddress
    ) external view returns (Asset memory);

    /// @notice Returns the collected paymaster fee for an asset by the protocol.
    /// @param assetId the asset id to get the fee for.
    /// @param paymaster the paymaster address claiming the fee
    function getCollectedPaymasterFee(
        uint24 assetId,
        address paymaster
    ) external view returns (uint256);

    /// @notice Returns the collected withdraw fee for an asset by the protocol.
    /// @param assetId The id of the asset.
    function getCollectedWithdrawFee(
        uint24 assetId
    ) external view returns (uint256);

    /// @notice Returns the data of a revoker.
    /// @param revokerId The id of the revoker.
    function getRevokerData(
        uint256 revokerId
    ) external view returns (RevokerData memory);

    /// @notice Returns if an external adaptor is supported.
    /// @param adaptorAddress The address of the adaptor.
    function isAdaptorSupported(
        address adaptorAddress
    ) external view returns (bool);

    /// @notice Returns if a nullifier is marked.
    /// @param nullifier The nullifier to check.
    function isMarkedNullifier(uint256 nullifier) external view returns (bool);

    /// @notice Returns if an array of nullifiers are marked.
    /// @param nullifiers The array of nullifiers to check.
    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory);

    /// @notice Returns the level hash of an empty merkle tree.
    function zeroes(uint8 level) external view returns (uint256);

    /// @notice Returns the depth of the commitment merkle tree.
    function getCommitmentTreeDepth() external view returns (uint8);

    /// @notice Returns the depth of the address merkle tree.
    function getAddressTreeDepth() external view returns (uint8);

    /// @notice Returns the next leaf index of the commitment merkle tree.
    function getCommitmentTreeNextLeafIndex() external view returns (uint32);

    /// @notice Returns the next leaf index of the address merkle tree.
    function getAddressTreeNextLeafIndex() external view returns (uint32);

    /// @notice Returns the lastest root of the commitment merkle tree.
    function getCommitmentTreeLastRoot() external view returns (uint256);

    /// @notice Returns the lastest root of the address merkle tree.
    function getAddressTreeLastRoot() external view returns (uint256);

    /// @notice Returns the index of the commitment tree's root history array. We store a history of 100 roots for proof verification purposes.
    function getCommitmentTreeCurrentRootIndex()
        external
        view
        returns (uint256);

    /// @notice Returns the index of the address tree's root history array.
    function getAddressTreeCurrentRootIndex() external view returns (uint256);

    /// @notice Returns whether a root value is a known commitment tree root.
    /// @param root The root value to check.
    function isKnownCommitmentTreeRoot(
        uint256 root
    ) external view returns (bool);

    /// @notice Returns whether a root value is a known address tree root.
    /// @param root The root value to check.
    function isKnownAddressTreeRoot(uint256 root) external view returns (bool);
}
