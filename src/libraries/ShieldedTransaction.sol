// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {FIELD_SIZE} from "../base/Constants.sol";
import {Asset, AssetLogic} from "./Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "./MerkleTree.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic} from "./QueuedMerkleTree.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {console} from "forge-std/console.sol";
/// @title ShieldedTransactionType enum representing types of shielded transactions
enum ShieldedTransactionType {
    DEPOSIT,
    TRANSFER,
    WITHDRAW,
    CALL_ADAPTOR
}

/// @title MemoType enum representing memo types for output notes
enum MemoType {
    NULL,
    SEMI,
    FULL
}

/// @title RevokerData struct representing revoker details
/// @param id                   Id of revoker
/// @param isActive             Flag indicating if revoker is enabled or disabled
/// @param revokerPublicKey     Public key of revoker
/// @param encryptionPublicKey  Public key of encryption with this revoker
struct RevokerData {
    uint16 id;
    bool isActive;
    uint256[2] revokerPublicKey;
    uint256[2] encryptionPublicKey;
}

/// @title ShieldedTransaction struct representing shielded transaction
///
/// @param txType               Type of transaction
/// @param revokerId            Id of revoker used for this transaction
/// @param addressTreeRoot      Recent merkle root of address tree
/// @param commitmentTreeRoot   Recent merkle root of commitment tree
/// @param feeData              Packed fee data (20-byte paymaster address + 12-byte fee value)
/// @param refundAddress        Blinded address to publicly refund assets to such as in adaptor transactions
/// @param pubAssets            Encoded (assetId + value) for publicly spent assets. If applicable, fee asset is
///                             the first element in this array
/// @param nullifiers           Revealed nullifiers of input/spent notes
/// @param commitments          New commitments of output notes to be inserted in tree
/// @param proof                Abi encoded ZK proof
/// @param assetsMemo           This is empty for non-TRANSFER transactions. For TRANSFER transactions,
///                             this is encrypted assets using sender's key that were transferred to receiver.
/// @param keysMemo             Encrypted keys with wich notesMemo is encrypted
/// @param notesMemo            Memos for output notes. This is list of encrypted notes' fields and sender data.
/// @param targetData           Target address (first 20-bytes) for withdraw/adapter concatenated with payload
struct ShieldedTransaction {
    ShieldedTransactionType txType;
    uint16 revokerId;
    uint256 addressTreeRoot;
    uint256 commitmentTreeRoot;
    uint256 feeData;
    uint256 refundAddress;
    uint248[] pubAssets;
    uint256[] nullifiers;
    uint256[] commitments;
    bytes proof;
    bytes assetsMemo;
    bytes keysMemo;
    bytes notesMemo;
    bytes targetData;
}

/// @title PubAsset struct representing public asset details
/// @param id     Asset id
/// @param value  Asset value
struct PubAsset {
    uint24 id;
    uint224 value;
}

struct Params {
    ShieldedTransactionType txType;
    uint16 revokerId;
    uint24 feeAssetId;
    uint96 feeValue;
    address paymaster;
    address target;
    PubAsset[] pubAssets;
    uint256 refundAddress;
    bytes targetPayload;
}

struct MemoParams {
    uint256[] commitments;
    bytes keysMemo;
    bytes assetsMemo;
    bytes notesMemo;
    bytes refundMemo;
}

/// @title ShieldedTransactionLogic library for shielded transaction logic
library ShieldedTransactionLogic {
    using MerkleTreeLogic for MerkleTree;
    using QueuedMerkleTreeLogic for QueuedMerkleTree;

    /// @notice Calculates the hash of a ShieldedTransaction
    /// @dev All of the omitted fields of ShieldedTransaction for hashing are public inputs
    ///      to the verifier, and tampering with any of those fields will result in invalid
    ///      proof anyway. `nullifiers` is exception for sake of including some element of
    ///      spent notes in the hash.
    /// @param self ShieldedTransaction
    /// @return Hash of the transaction
    function hash(
        ShieldedTransaction memory self
    ) public pure returns (uint256) {
        uint256 txHash = uint256(
            keccak256(
                abi.encode(
                    self.txType,
                    self.feeData,
                    self.refundAddress,
                    self.nullifiers,
                    self.assetsMemo,
                    self.keysMemo,
                    self.targetData
                )
            )
        ) % FIELD_SIZE;

        return txHash;
    }

    /// @notice Validates a shielded transaction
    /// @param stx ShieldedTransaction to be executed
    /// @param addressTree Address `MerkleTree` state in this contract
    /// @param commitmentTree Commitment `MerkleTree` state in this contract
    /// @param markedNullifiers Mapping of nullifiers that are already marked
    /// @param supportedAdaptors Mapping of supported external adaptor addresses
    function validate(
        ShieldedTransaction calldata stx,
        MerkleTree storage addressTree,
        QueuedMerkleTree storage commitmentTree,
        mapping(uint256 => uint32) storage markedNullifiers,
        mapping(address => bool) storage supportedAdaptors,
        mapping(uint256 => RevokerData) storage revokerDataMap,
        address verifier,
        address hasher
    ) external {
        RevokerData memory revokerData = revokerDataMap[stx.revokerId];

        if (!revokerData.isActive) {
            revert IPool.InvalidRevoker(stx.revokerId);
        }

        if (!addressTree.isKnownRoot(stx.addressTreeRoot)) {
            revert IPool.UnknownAddressTreeRoot();
        }

        if (!commitmentTree.isKnownRoot(stx.commitmentTreeRoot)) {
            revert IPool.UnknownCommitmentTreeRoot();
        }

        if (
            stx.txType == ShieldedTransactionType.CALL_ADAPTOR &&
            !supportedAdaptors[address(bytes20(stx.targetData))]
        ) {
            revert IPool.UnsupportedAdaptor();
        }

        _checkAndMarkNullifiers(stx, commitmentTree, markedNullifiers);

        if (!_verifyProof(stx, revokerData, hasher, verifier)) {
            revert IPool.InvalidTransactionProof();
        }
    }

    /// @notice Executes a shielded transaction
    /// @param stx ShieldedTransaction to be executed
    /// @param commitmentTree Commitment `MerkleTree` state in this contract
    /// @param assets Mapping of assetId to Asset
    /// @param adaptorHandler Address of the adaptor handler contract responsible for handling DeFi adaptor ops
    /// @param paymasterFees Mapping of paymaster address to assetId to fee value
    function execute(
        ShieldedTransaction calldata stx,
        QueuedMerkleTree storage commitmentTree,
        mapping(uint24 => Asset) storage assets,
        mapping(address => mapping(uint24 => uint256)) storage paymasterFees,
        mapping(uint24 => uint256) storage withdrawFees,
        address hasher,
        address adaptorHandler,
        uint256 withdrawFeeBps
    ) external {
        Params memory params = _copyParamsToMemory(stx);
        MemoParams memory memoParams = _copyMemoParamsToMemory(stx);

        // Credit paymaster fees
        _creditPaymasterFee(paymasterFees, params);

        // Receive any deposits
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            _receivePubAssets(assets, params.pubAssets, msg.sender);
        }

        // Transfer any withdrawals
        if (stx.txType == ShieldedTransactionType.WITHDRAW) {
            _transferPubAssets(
                assets,
                withdrawFees,
                params.pubAssets,
                params.target,
                withdrawFeeBps
            );
        }

        // Perform any conversions
        if (stx.txType == ShieldedTransactionType.CALL_ADAPTOR) {
            _transferPubAssets(
                assets,
                withdrawFees,
                params.pubAssets,
                adaptorHandler,
                0
            );
            _handleAdaptorCall(
                assets,
                hasher,
                adaptorHandler,
                params,
                memoParams
            );
        }

        _printNotes(commitmentTree, params, memoParams);
    }

    /**
     *
     * @param self ShieldedTransaction to convert to a proper verifier input
     * @param revokerData The RevokerData used for this transaction
     * @param hasher The address of the hasher contract
     * @return Calldata bytes for appropriate verifier contract
     * @dev We divide the public inputs into 2 chunks to avoid stack too deep error
     */
    function _toVerifierInput(
        ShieldedTransaction calldata self,
        RevokerData memory revokerData,
        address hasher
    ) internal view returns (bytes memory) {
        bytes memory pubDataChunk1;
        {
            uint256 nOuts = self.commitments.length;
            uint256 nPubs = self.pubAssets.length;
            bytes memory padZeroBytes = new bytes((nOuts - nPubs) * 32);

            uint256[] memory pubAssetIds = new uint256[](nPubs);
            uint256[] memory pubValues = new uint256[](nPubs);
            for (uint8 i; i < nPubs; ++i) {
                pubAssetIds[i] = uint24(bytes3(bytes31(self.pubAssets[i])));
                pubValues[i] = uint224(self.pubAssets[i]);
            }

            pubDataChunk1 = abi.encodePacked(
                self.addressTreeRoot,
                self.commitmentTreeRoot,
                hash(self),
                self.txType == ShieldedTransactionType.DEPOSIT
                    ? uint256(0)
                    : uint256(1),
                pubAssetIds,
                padZeroBytes,
                pubValues,
                padZeroBytes
            );
        }

        bytes memory pubDataChunk2;
        {
            pubDataChunk2 = abi.encodePacked(
                abi.encodePacked(self.nullifiers),
                revokerData.revokerPublicKey[0],
                revokerData.revokerPublicKey[1],
                abi.encodePacked(self.commitments),
                self.refundAddress,
                revokerData.encryptionPublicKey[0],
                revokerData.encryptionPublicKey[1]
                // self.notesMemo
            );
        }

        // Performing sequential hashing of encrypted data derived from notesMemo
        uint256 encryptedDataHash;
        {
            require(
                self.notesMemo.length % 32 == 0,
                "Invalid notesMemo length"
            );

            // 1. Split notesMemo into values array each 32 bytes
            uint256[] memory values = new uint256[](self.notesMemo.length / 32);
            for (uint256 i = 0; i < self.notesMemo.length / 32; i++) {
                values[i] = uint256(
                    bytes32(self.notesMemo[i * 32:(i + 1) * 32])
                );
            }

            // 2. Hash encryptedDataEncryptionKeySeed (first 3 values)
            uint256[] memory encryptedDataEncryptionKeySeed = new uint256[](3);
            for (uint256 i = 0; i < 3; i++) {
                encryptedDataEncryptionKeySeed[i] = values[i];
            }
            console.log("Encrypted DEK seed:");
            console.logUint(encryptedDataEncryptionKeySeed[0]);
            console.logUint(encryptedDataEncryptionKeySeed[1]);
            console.logUint(encryptedDataEncryptionKeySeed[2]);
            uint256 keySeedHash = IHasher(hasher).hash(
                encryptedDataEncryptionKeySeed
            ); // 3
            console.log("Encrypted DEK seed hash:");
            console.logUint(keySeedHash);

            // 3. Hash encryptedRefundData (next 4 values)
            uint256[] memory refundInputs = new uint256[](4);
            for (uint256 i = 0; i < 4; i++) {
                refundInputs[i] = values[i + 3];
            }
            console.log("Encrypted refund data:");
            console.logUint(refundInputs[0]);
            console.logUint(refundInputs[1]);
            console.logUint(refundInputs[2]);
            console.logUint(refundInputs[3]);
            uint256 refundHash = IHasher(hasher).hash(refundInputs); // 4
            console.log("Encrypted refund data hash:");
            console.logUint(refundHash);
            // 4. Hash each encryptedNote (4 values each)
            uint256 nOuts = self.commitments.length;
            uint256[] memory noteHashes = new uint256[](nOuts);
            for (uint256 i = 0; i < nOuts; i++) {
                uint256[] memory noteInputs = new uint256[](4);
                for (uint256 j = 0; j < 4; j++) {
                    noteInputs[j] = values[7 + (i * 4) + j];
                }
                console.log("Encrypted note data:");
                console.logUint(noteInputs[0]);
                console.logUint(noteInputs[1]);
                console.logUint(noteInputs[2]);
                console.logUint(noteInputs[3]);
                noteHashes[i] = IHasher(hasher).hash(noteInputs); // 4
            }

            for (uint256 i = 0; i < nOuts; i++) {
                console.log("Encrypted note hash:");
                console.logUint(noteHashes[i]);
            }

            // 5. Final hash combining all hashes
            uint256[] memory finalInputs = new uint256[](2 + nOuts);
            finalInputs[0] = keySeedHash;
            finalInputs[1] = refundHash;
            for (uint256 i = 0; i < nOuts; i++) {
                finalInputs[2 + i] = noteHashes[i];
            }

            encryptedDataHash = IHasher(hasher).hash(finalInputs); // 4
            console.log("FINAL HASH (encryptedDataHash public signal):");
            console.logUint(encryptedDataHash);
        }

        bytes memory verifierParams = abi.encodePacked(
            self.proof,
            pubDataChunk1,
            pubDataChunk2,
            encryptedDataHash
        );

        return verifierParams;
    }

    function _handleAdaptorCall(
        mapping(uint24 => Asset) storage assets,
        address hasher,
        address adaptorHandler,
        Params memory params,
        MemoParams memory memoParams
    ) internal {
        PubAsset[] memory outPubAssets = IAdaptorHandler(adaptorHandler)
            .handleAdaptor(
                params.target,
                params.pubAssets,
                params.targetPayload
            );

        _receivePubAssets(assets, outPubAssets, adaptorHandler);

        /// @dev Creating commitments and output noteMemos for received tokens. This is done on the protocol side for CALL_ADAPTOR txns because the exact value of converted tokens can only be determined after executing the tx.
        /// @dev `refundAddress` is used as the recipient's blinded address.
        /// @dev `refundAddressMemo` contains the encrypted blinding factor which can only be decrypted by the owner of `refundAddress`. This blinding needs to be submitted as a proof to prove ownership over the refund notes.
        uint256 outLen = outPubAssets.length;
        uint256[] memory pubCms = new uint256[](outLen);

        for (uint8 i = 0; i < outLen; ++i) {
            pubCms[i] = IHasher(hasher).hash(
                [
                    outPubAssets[i].id,
                    params.refundAddress,
                    outPubAssets[i].value
                ]
            );
            memoParams.refundMemo = abi.encodePacked(
                memoParams.refundMemo,
                outPubAssets[i].id,
                outPubAssets[i].value
            );
        }

        memoParams.commitments = _concat(memoParams.commitments, pubCms);
    }

    function _creditPaymasterFee(
        mapping(address => mapping(uint24 => uint256)) storage paymasterFees,
        Params memory params
    ) internal {
        uint256 feeValue = params.feeValue;

        if (feeValue != 0) {
            paymasterFees[params.paymaster][params.feeAssetId] += feeValue;
        }
    }

    function _receivePubAssets(
        mapping(uint24 => Asset) storage assets,
        PubAsset[] memory pubAssets,
        address from
    ) internal {
        uint256 count = pubAssets.length;

        for (uint8 i = 0; i < count; ) {
            AssetLogic.receiveAsset({
                assets: assets,
                from: from,
                assetId: pubAssets[i].id,
                value: pubAssets[i].value
            });

            unchecked {
                ++i;
            }
        }
    }

    function _transferPubAssets(
        mapping(uint24 => Asset) storage assets,
        mapping(uint24 => uint256) storage withdrawFees,
        PubAsset[] memory pubAssets,
        address to,
        uint256 feeBps
    ) internal {
        uint256 count = pubAssets.length;

        uint256 fee;
        for (uint8 i = 0; i < count; ) {
            if (pubAssets[i].value == 0) {
                unchecked {
                    ++i;
                }
                continue;
            }

            fee = feeBps == 0 ? 0 : (pubAssets[i].value * feeBps) / 10000;
            AssetLogic.transferAsset({
                assets: assets,
                to: to,
                assetId: pubAssets[i].id,
                value: pubAssets[i].value - fee
            });

            if (fee != 0) {
                withdrawFees[pubAssets[i].id] += fee;
            }

            unchecked {
                ++i;
            }
        }
    }

    function _verifyProof(
        ShieldedTransaction calldata stx,
        RevokerData memory revokerData,
        address hasher,
        address verifier
    ) internal view returns (bool) {
        uint16 vId = IVerifier(verifier).getTransactionVerifierId(
            stx.nullifiers.length,
            stx.commitments.length
        );
        bytes memory vInp = _toVerifierInput(stx, revokerData, hasher);
        return IVerifier(verifier).verifyTransactionProof(vId, vInp);
    }

    /// @dev This also prevents any duplicate nullifiers
    function _checkAndMarkNullifiers(
        ShieldedTransaction calldata stx,
        QueuedMerkleTree storage commitmentTree,
        mapping(uint256 => uint32) storage markedNullifiers
    ) internal {
        uint256 numNullifiers = stx.nullifiers.length;
        uint32 nextIdx = commitmentTree.nextLeafIndex;

        for (uint8 i = 0; i < numNullifiers; ) {
            uint256 nullifier = stx.nullifiers[i];
            if (markedNullifiers[nullifier] != 0) {
                revert IPool.DoubleSpend(nullifier);
            }

            /// @dev adding 1 to nextIdx to avoid marking the first nullifier as 0, as 0 means nullifier is not marked
            markedNullifiers[nullifier] = nextIdx + 1;
            emit IPool.NullifierMarked(nullifier, markedNullifiers[nullifier]);

            unchecked {
                ++i;
            }
        }
    }

    function _printNotes(
        QueuedMerkleTree storage tree,
        Params memory params,
        MemoParams memory memoParams
    ) internal {
        // offset = nextLeafIdx + currentQueueLen
        uint32 leafIndexOffset = tree.nextLeafIndex +
            (tree.queueEndIndex - tree.queueStartIndex);

        for (uint8 i = 0; i < memoParams.commitments.length; ++i) {
            uint32 leafIndex = leafIndexOffset + i;
            emit IPool.Commitment(leafIndex, memoParams.commitments[i]);
        }

        tree.queueLeaves(memoParams.commitments);

        uint32 lastLeafIndex = tree.nextLeafIndex +
            (tree.queueEndIndex - tree.queueStartIndex) -
            1;

        emit IPool.Receipt(
            params.txType,
            params.revokerId,
            lastLeafIndex,
            params.target,
            params.feeAssetId,
            params.feeValue,
            params.paymaster,
            memoParams.keysMemo,
            memoParams.assetsMemo,
            memoParams.notesMemo,
            memoParams.refundMemo
        );
    }

    function _copyParamsToMemory(
        ShieldedTransaction calldata stx
    ) internal pure returns (Params memory) {
        Params memory params;
        uint256 pubLen = stx.pubAssets.length;

        // non transfer tx & transfer tx with fee, extracting the fee details from feeData
        if (pubLen != 0) {
            params.paymaster = address(uint160(stx.feeData >> (24 + 72)));

            // Extract the feeAssetId (3 bytes)
            params.feeAssetId = uint24(stx.feeData >> 72);

            // Extract the feeValue (9 bytes)
            params.feeValue = uint72(stx.feeData);
        }

        params.pubAssets = new PubAsset[](pubLen);
        for (uint8 i = 0; i < pubLen; ++i) {
            // Extract first 3 bytes assetId
            params.pubAssets[i].id = uint24(bytes3(bytes31(stx.pubAssets[i])));
            // Extract last 28 bytes value
            params.pubAssets[i].value = uint224(stx.pubAssets[i]);

            /// @dev for transfer tx and feeAsset pushed into pubAssets, the pubAssets value will become 0, but thats fine as pubAssets is not used in transfer tx. Only used in other types tx to move assets.
            if (params.pubAssets[i].id == params.feeAssetId) {
                params.pubAssets[i].value =
                    params.pubAssets[i].value -
                    params.feeValue;
            }
        }

        params.txType = stx.txType;
        params.revokerId = stx.revokerId;
        params.target = address(bytes20(stx.targetData));
        if (params.target != address(0)) {
            params.targetPayload = bytes(stx.targetData[20:]);
        }

        if (stx.txType == ShieldedTransactionType.CALL_ADAPTOR) {
            params.refundAddress = stx.refundAddress;
        }

        return params;
    }

    function _copyMemoParamsToMemory(
        ShieldedTransaction calldata stx
    ) internal pure returns (MemoParams memory) {
        MemoParams memory memoParams;

        memoParams.commitments = stx.commitments;
        memoParams.keysMemo = stx.keysMemo;
        memoParams.notesMemo = stx.notesMemo;

        if (stx.txType == ShieldedTransactionType.TRANSFER) {
            memoParams.assetsMemo = stx.assetsMemo;
        } else {
            memoParams.assetsMemo = abi.encodePacked(stx.pubAssets);
        }

        return memoParams;
    }

    function _concat(
        uint256[] memory a,
        uint256[] memory b
    ) internal pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](a.length + b.length);
        for (uint8 i = 0; i < a.length; ) {
            result[i] = a[i];
            unchecked {
                ++i;
            }
        }
        for (uint8 i = 0; i < b.length; ) {
            result[a.length + i] = b[i];
            unchecked {
                ++i;
            }
        }
        return result;
    }
}
