// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {PoseidonT4} from "poseidon-solidity/PoseidonT4.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {Verifier} from "../core/Verifier.sol";
import {FIELD_SIZE} from "../core/Constants.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {Asset, AssetLogic} from "./Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "./MerkleTree.sol";
import {console} from "forge-std/Test.sol";

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

/// @title VerifierAndAdpAddress struct representing verifier and adaptor handler addresses to reduce no. of params for the `execute` function
struct VerifierAndAdpAddress {
    address verifier;
    address adaptorHandler;
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
/// @param assetMemo        This is empty for non-TRANSFER transactions. For TRANSFER transactions,
///                         this is encrypted assets using sender's key that were transferred to receiver.
/// @param noteMemos         Memos for output notes. This is list of encrypted notes' fields.
/// @param feeData          Packed fee data (20-byte paymaster address + 12-byte fee value)
/// @param beneficiary      Stealth address for any public fund to shielded account (e.g. in CONVERT type tx)
/// @param beneficiaryMemo  Memo for beneficiary stealth address. This is encrypted blinding factor which
///                         is used to generate `beneficiary` stealth address
/// @param target           This is either a withdraw address in case of `WITHDRAW` transaction or
///                         a targetted adaptor address in case of `CONVERT` transaction
/// @param targetPayload    Payload for target contract (if applicable)
/// @param revokerId        Id of revoker used for this transaction
/// @param complianceMemo   Encrypted compliance data
struct ZTransaction {
    ZTransactionType txType;
    uint16 revokerId;
    uint256 addressTreeRoot;
    uint256 commitmentTreeRoot;
    uint256 feeData;
    bytes proof;
    // bytes complianceData; // revokerId + complianceMemo
    uint24[] pubAssetIds; // First index is always fee asset
    uint256[] pubValues;
    uint256[] nullifiers;
    uint256[] commitments;
    bytes[] noteMemos;
    bytes assetMemo;
    bytes complianceMemo;
    bytes targetData; // target address + payload
    bytes refundData; // refund address + memo
}

/// @title ZTransactionLogic library for shielded transaction logic
library ZTransactionLogic {
    using MerkleTreeLogic for MerkleTree;

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
                        self.feeData,
                        self.nullifiers,
                        self.noteMemos,
                        self.assetMemo,
                        self.targetData,
                        self.refundData
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
    function execute(
        ZTransaction memory ztx,
        MerkleTree storage addressTree,
        MerkleTree storage commitmentTree,
        mapping(uint24 => Asset) storage assets,
        mapping(address => bool) storage adaptors,
        mapping(uint256 => bool) storage markedNullifiers,
        mapping(uint256 => RevokerData) storage revokers,
        VerifierAndAdpAddress memory verifierAndAdpAddress,
        mapping(address => mapping(uint24 => uint256)) storage paymasterFees
    ) external {
        _validateTransaction(
            addressTree,
            commitmentTree,
            adaptors,
            markedNullifiers,
            revokers,
            verifierAndAdpAddress.verifier,
            ztx
        );

        // Transfer any fees
        _transferFee(ztx, paymasterFees);

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
            _transferToExceptFee(assets, address(bytes20(ztx.targetData)), ztx);
        }

        // Perform any conversions
        if (ztx.txType == ZTransactionType.CONVERT) {
            _transferToExceptFee(
                assets,
                verifierAndAdpAddress.adaptorHandler,
                ztx
            );
            _convert(assets, verifierAndAdpAddress.adaptorHandler, ztx);
        }

        uint256 lastLeafIndex = _mintNotes(
            commitmentTree,
            ztx.commitments
            // ztx.noteMemos
        );

        _emitReceipt(ztx, lastLeafIndex);
    }

    function _emitReceipt(
        ZTransaction memory ztx,
        uint256 lastLeafIdx
    ) internal {
        bytes memory assetMemo;
        if (ztx.txType == ZTransactionType.TRANSFER) {
            // Encrypted transacted assets
            assetMemo = ztx.assetMemo;
        } else {
            // Publicly transacted assets
            bytes32 asset;
            for (uint8 i = 0; i < ztx.pubAssetIds.length; ) {
                // Asset value is assumed to be 28 bytes max
                asset = bytes31(
                    bytes.concat(
                        bytes3(ztx.pubAssetIds[i]),
                        bytes28(bytes32(ztx.pubValues[i]))
                    )
                );
                assetMemo = abi.encodePacked(assetMemo, asset);
                unchecked {
                    ++i;
                }
            }
        }

        emit IPool.Receipt(
            ztx.txType,
            ztx.revokerId,
            uint32(lastLeafIdx),
            address(bytes20(ztx.targetData)),
            ztx.feeData,
            assetMemo,
            ztx.complianceMemo,
            ztx.noteMemos
        );
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
                bytes32(self.refundData),
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
                address(bytes20(ztx.targetData)),
                ztx.pubAssetIds,
                ztx.pubValues,
                ztx.targetData
            );

        _receiveAssetsFrom(assets, adaptorHandler, outAssetIds, outValues);

        uint256 cmLen = ztx.commitments.length;
        uint256 outLen = outAssetIds.length;
        uint256 newCmLen = cmLen + outLen;

        uint256[] memory newCommitments = new uint256[](newCmLen);
        bytes[] memory newMemos = new bytes[](newCmLen);

        for (uint8 i = 0; i < cmLen; ) {
            newCommitments[i] = ztx.commitments[i];
            newMemos[i] = ztx.noteMemos[i];

            unchecked {
                ++i;
            }
        }

        uint256 refundAddr = uint256(bytes32(ztx.refundData));
        for (uint8 i = 0; i < outLen; ) {
            newCommitments[i + cmLen] = PoseidonT4.hash(
                [outAssetIds[i], refundAddr, outValues[i]]
            );
            newMemos[i + cmLen] = abi.encodePacked(
                MemoType.SEMI,
                outAssetIds[i],
                refundAddr,
                outValues[i],
                ztx.refundData
            );

            unchecked {
                ++i;
            }
        }

        ztx.commitments = newCommitments;
        ztx.noteMemos = newMemos;
    }

    function _transferFee(
        ZTransaction memory ztx,
        mapping(address => mapping(uint24 => uint256)) storage paymasterFees
    ) internal {
        uint256 feeValue = uint256(uint96(ztx.feeData));
        console.log("Fee value:", feeValue);
        if (feeValue != 0) {
            address paymaster = address(bytes20(bytes32(ztx.feeData)));
            paymasterFees[paymaster][ztx.pubAssetIds[0]] += feeValue;
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

        if (!addressTree.isKnownRoot(ztx.addressTreeRoot)) {
            // TODO: reintroduce this check
            // console2.log("ztx.addressTreeRoot", ztx.addressTreeRoot);
            // console2.log("addressTreeRoot", addressTree.getMerkleRoot(1));
            // revert IPool.UnknownAddressTreeRoot();
        }

        // Check recent merkle root
        if (!commitmentTree.isKnownRoot(ztx.commitmentTreeRoot)) {
            revert IPool.UnknownCommitmentTreeRoot();
        }

        if (
            ztx.txType == ZTransactionType.CONVERT &&
            !supportedAdaptors[address(bytes20(ztx.targetData))]
        ) {
            revert IPool.UnsupportedAdaptor();
        }

        // Verify ZK proof
        if (!Verifier(verifier).verifyTransactionProof(ztx, cKeys)) {
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
        uint256[] memory commitments
    )
        internal
        returns (
            // bytes[] memory outMemos
            uint256
        )
    {
        uint256 nextIndex = MerkleTreeLogic.insert(tree, commitments);
        uint256 cmLen = commitments.length;

        for (uint256 i = 0; i < cmLen; ) {
            // emit IPool.Announcement(
            //     nextIndex - cmLen + i,
            //     commitments[i],
            //     outMemos[i]
            // );
            emit IPool.Commitment(nextIndex - cmLen + i, commitments[i]);
            unchecked {
                ++i;
            }
        }

        return nextIndex - 1;
    }
}
