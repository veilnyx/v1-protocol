// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {PoseidonT4} from "poseidon-solidity/PoseidonT4.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {Verifier} from "../core/Verifier.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {Asset, AssetLogic} from "./Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "./MerkleTree.sol";

/// @title ZTransactionType enum representing types of shielded transactions
enum ZTransactionType {
    DEPOSIT,
    TRANSFER,
    WITHDRAW,
    CONVERT
}

/// @title MemoType enum representing memo types for output notes
enum MemoType {
    NULL,
    SEMI,
    FULL
}

/// @title RevokerData struct representing revoker details
struct RevokerData {
    uint16 id;
    bool isActive;
    uint256[2] revokerPublicKey;
    uint256[2] encryptionPublicKey;
    bytes metadata;
}

/// @title ZTransaction struct representing shielded transaction
///
/// @param txType           Type of transaction
/// @param proof            Abi encoded proof
/// @param addressTreeRoot          Recent merkle root of address tree
/// @param commitmentTreeRoot       Recent merkle root of commitment tree
/// @param pubAssetIds      Asset ids for public asset transfers (if applicable, fee asset is always first)
/// @param pubValues        Values (in same order of asset ids) for public asset transfers
/// @param nullifiers       Revealed nullifiers of input/spent notes
/// @param commitments      New commitments of output notes to be inserted in tree
/// @param inMemos          Memo for input notes (helpful for parsing transaction history). This is
///                         encrypted (by sender's key), packed indices of input notes
/// @param outMemos         Memos for output notes. This is list of encrypted notes' fields.
/// @param feeData          Packed fee data (20-byte paymaster address + 12-byte fee value)
/// @param beneficiary      Stealth address for any public fund to shielded account (e.g. in CONVERT type tx)
/// @param beneficiaryMemo  Memo for beneficiary stealth address. This is encrypted blinding factor which
///                         is used to generate `beneficiary` stealth address
/// @param target           This is either a withdraw address in case of `WITHDRAW` transaction or
///                         a targetted adaptor address in case of `CONVERT` transaction
/// @param targetPayload    Payload for target contract (if applicable)
/// @param revokerId Id of compliance keys used for this transaction
/// @param complianceMemo   Encrypted compliance data
struct ZTransaction {
    ZTransactionType txType;
    bytes proof;
    uint256 addressTreeRoot;
    uint256 commitmentTreeRoot;
    // Public data
    uint24[] pubAssetIds; // First index is always fee asset
    uint256[] pubValues;
    // Notes info
    uint256[] nullifiers;
    uint256[] commitments;
    bytes inMemos;
    bytes[] outMemos;
    // Fees info
    uint256 feeData;
    uint256 beneficiary;
    bytes beneficiaryMemo;
    address target;
    bytes targetPayload;
    // Compliance params
    uint16 revokerId;
    bytes complianceMemo;
}

/// @title ZTransactionLogic library for shielded transaction logic
library ZTransactionLogic {
    using MerkleTreeLogic for MerkleTree;

    uint256 constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @notice Calculates the hash of a ZTransaction
    /// @dev All of the omitted fields of ZTransaction for hashing are public inputs
    ///      to the verifier, and tampering with any of those fields will result in invalid
    ///      proof anyway. `nullifiers` is exception for sake of including some element of
    ///      spent notes in the hash.
    /// @param self ZTransaction
    /// @return Hash of the transaction
    function hash(ZTransaction memory self) public pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        self.txType,
                        self.nullifiers,
                        self.inMemos,
                        self.outMemos,
                        self.feeData,
                        self.beneficiaryMemo,
                        self.target,
                        self.targetPayload
                    )
                )
            ) % FIELD_SIZE;
    }

    /// @notice Executes a shielded transaction
    /// @param ztx ZTransaction to be executed
    /// @param addressTree Address `MerkleTree` state in this contract
    /// @param commitmentTree Commitment `MerkleTree` state in this contract
    /// @param assets Mapping of assetId to Asset
    /// @param adaptors Mapping of supported external adaptor addresses
    /// @param markedNullifiers Mapping of nullifiers that are already marked
    /// @param verifier Verifier contract address
    /// @param adaptorHandler Adaptor contract address
    function execute(
        ZTransaction memory ztx,
        MerkleTree storage addressTree,
        MerkleTree storage commitmentTree,
        mapping(uint24 => Asset) storage assets,
        mapping(address => bool) storage adaptors,
        mapping(uint256 => bool) storage markedNullifiers,
        mapping(uint256 => RevokerData) storage revokers,
        address verifier,
        address adaptorHandler
    ) external {
        _validateTransaction(
            addressTree,
            commitmentTree,
            adaptors,
            markedNullifiers,
            revokers,
            verifier,
            ztx
        );

        // Transfer any fees
        _transferFee(assets, ztx);

        // Receive any deposits
        if (ztx.txType == ZTransactionType.DEPOSIT) {
            _receiveAssetsFrom(
                assets,
                msg.sender,
                ztx.pubAssetIds,
                ztx.pubValues
            );
        }

        // Transfer any withdrawals
        if (ztx.txType == ZTransactionType.WITHDRAW) {
            _transferToExceptFee(assets, ztx.target, ztx);
        }

        // Perform any conversions
        if (ztx.txType == ZTransactionType.CONVERT) {
            _transferToExceptFee(assets, adaptorHandler, ztx);
            _convert(assets, adaptorHandler, ztx);
        }

        _mintNotes(commitmentTree, ztx.commitments, ztx.inMemos, ztx.outMemos);

        emit IPool.ComplianceMemo(ztx.complianceMemo);
    }

    /**
     *
     * @param self ZTransaction to convert to a proper verifier input
     * @param cKeys The RevokerData used for this transaction
     * @param selector Selector of verifier contract
     * @return Calldata bytes for appropriate verifier contract
     * @dev We divide the public inputs into 2 chunks to avoid stack too deep error
     */
    function toVerifierInput(
        ZTransaction memory self,
        RevokerData memory cKeys,
        bytes4 selector
    ) public pure returns (bytes memory) {
        bytes memory pubDataChunk1;
        {
            uint256 nOuts = self.commitments.length;
            uint256 nPubs = self.pubAssetIds.length;
            uint256[] memory zeros = new uint256[](nOuts - nPubs);

            pubDataChunk1 = abi.encodePacked(
                self.addressTreeRoot,
                self.commitmentTreeRoot,
                hash(self),
                self.txType == ZTransactionType.DEPOSIT
                    ? uint256(0)
                    : uint256(1),
                self.pubAssetIds,
                zeros,
                self.pubValues,
                zeros
            );
        }

        bytes memory pubDataChunk2;
        {
            pubDataChunk2 = abi.encodePacked(
                abi.encodePacked(self.nullifiers),
                bytes32(cKeys.revokerPublicKey[0]),
                bytes32(cKeys.revokerPublicKey[1]),
                abi.encodePacked(self.commitments),
                self.beneficiary,
                cKeys.encryptionPublicKey[0],
                cKeys.encryptionPublicKey[1],
                self.complianceMemo
            );
        }

        bytes memory verifierCallData = abi.encodePacked(
            // Verifier's `verifyProof` selector
            selector,
            // Proof
            self.proof,
            // Public inputs
            pubDataChunk1,
            pubDataChunk2
        );

        return verifierCallData;
    }

    function _convert(
        mapping(uint24 => Asset) storage assets,
        address adaptorHandler,
        ZTransaction memory ztx
    ) internal {
        (
            uint24[] memory outAssetIds,
            uint256[] memory outValues
        ) = IAdaptorHandler(adaptorHandler).handleAdaptor(
                ztx.target,
                ztx.pubAssetIds,
                ztx.pubValues,
                ztx.targetPayload
            );

        _receiveAssetsFrom(assets, adaptorHandler, outAssetIds, outValues);

        uint256 cmLen = ztx.commitments.length;
        uint256 outLen = outAssetIds.length;
        uint256 newCmLen = cmLen + outLen;

        uint256[] memory newCommitments = new uint256[](newCmLen);
        bytes[] memory newMemos = new bytes[](newCmLen);

        for (uint8 i = 0; i < cmLen; ) {
            newCommitments[i] = ztx.commitments[i];
            newMemos[i] = ztx.outMemos[i];

            unchecked {
                ++i;
            }
        }

        for (uint8 i = 0; i < outLen; ) {
            newCommitments[i + cmLen] = PoseidonT4.hash(
                [outAssetIds[i], ztx.beneficiary, outValues[i]]
            );
            newMemos[i + cmLen] = abi.encodePacked(
                MemoType.SEMI,
                outAssetIds[i],
                ztx.beneficiary,
                outValues[i],
                ztx.beneficiaryMemo
            );

            unchecked {
                ++i;
            }
        }

        ztx.commitments = newCommitments;
        ztx.outMemos = newMemos;
    }

    function _transferFee(
        mapping(uint24 => Asset) storage assets,
        ZTransaction memory ztx
    ) internal {
        uint256 feeValue = uint256(uint96(ztx.feeData));

        if (feeValue != 0) {
            address paymaster = address(bytes20(bytes32(ztx.feeData)));
            AssetLogic.transferAsset({
                assets: assets,
                to: paymaster,
                assetId: ztx.pubAssetIds[0],
                value: feeValue
            });
        }
    }

    function _transferToExceptFee(
        mapping(uint24 => Asset) storage assets,
        address to,
        ZTransaction memory ztx
    ) internal {
        uint256 pubAssetCount = ztx.pubAssetIds.length;
        uint256 feeValue = uint256(uint96(ztx.feeData));
        ztx.pubValues[0] = ztx.pubValues[0] - feeValue;

        if (ztx.pubValues[0] != 0) {
            AssetLogic.transferAsset({
                assets: assets,
                to: to,
                assetId: ztx.pubAssetIds[0],
                value: ztx.pubValues[0]
            });
        }

        for (uint8 i = 1; i < pubAssetCount; ) {
            AssetLogic.transferAsset({
                assets: assets,
                to: to,
                assetId: ztx.pubAssetIds[i],
                value: ztx.pubValues[i]
            });

            unchecked {
                ++i;
            }
        }
    }

    function _receiveAssetsFrom(
        mapping(uint24 => Asset) storage assets,
        address from,
        uint24[] memory assetIds,
        uint256[] memory values
    ) internal {
        uint256 count = assetIds.length;
        for (uint8 i = 0; i < count; ) {
            AssetLogic.receiveAsset({
                assets: assets,
                from: from,
                assetId: assetIds[i],
                value: values[i]
            });

            unchecked {
                ++i;
            }
        }
    }

    function _validateTransaction(
        MerkleTree storage addressTree,
        MerkleTree storage commitmentTree,
        mapping(address => bool) storage supportedAdaptors,
        mapping(uint256 => bool) storage markedNullifiers,
        mapping(uint256 => RevokerData) storage cKeysMap,
        address verifier,
        ZTransaction memory ztx
    ) internal {
        RevokerData memory cKeys = cKeysMap[ztx.revokerId];

        if (!cKeys.isActive) {
            revert IPool.InvalidRevoker(ztx.revokerId);
        }

        // Check recent merkle root
        if (!commitmentTree.isKnownRoot(ztx.commitmentTreeRoot)) {
            revert IPool.UnknownMerkleRoot();
        }

        if (!addressTree.isKnownRoot(ztx.addressTreeRoot)) {
            // revert IPool.UnknownMerkleRoot();
        }

        if (
            ztx.txType == ZTransactionType.CONVERT &&
            !supportedAdaptors[ztx.target]
        ) {
            revert IPool.UnsupportedAdaptor();
        }

        // Verify ZK proof
        if (!Verifier(verifier).verifyTransactionProof(ztx, cKeys)) {
            // TODO: might have to include `verifyTransactionProof` in ZTransactionLogic library if merkle tree has to be sent for
            revert IPool.InvalidProof();
        }

        // Check double spend and mark nullifiers
        _checkAndMarkNullifiers(markedNullifiers, ztx.nullifiers);
    }

    /// @dev This also prevents any duplicate nullifiers
    function _checkAndMarkNullifiers(
        mapping(uint256 => bool) storage markedNullifiers,
        uint256[] memory nullifiers
    ) internal {
        for (uint256 i = 0; i < nullifiers.length; ) {
            if (markedNullifiers[nullifiers[i]]) {
                revert IPool.DoubleSpend(nullifiers[i]);
            }

            markedNullifiers[nullifiers[i]] = true;
            emit IPool.NullifierMarked(nullifiers[i]);

            unchecked {
                ++i;
            }
        }
    }

    function _mintNotes(
        MerkleTree storage tree,
        uint256[] memory commitments,
        bytes memory inMemos,
        bytes[] memory outMemos
    ) internal {
        uint256 nextIndex = MerkleTreeLogic.insert(tree, commitments);
        uint256 cmLen = commitments.length;

        for (uint256 i = 0; i < cmLen; ) {
            emit IPool.Announcement(
                nextIndex - cmLen + i,
                commitments[i],
                outMemos[i]
            );
            unchecked {
                ++i;
            }
        }

        emit IPool.InputNoteMemos(inMemos);
    }
}
