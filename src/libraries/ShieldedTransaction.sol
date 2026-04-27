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
import {INebraUpa} from "../interfaces/INebraUpa.sol";

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
/// @param betaUHF              Beta UHF value generated off-chain from PoseidonEncrytion(encryptedInputs) and used in UHF (gamma) = ∑i (a+β)^i⋅Di modp.
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
    uint256 betaUHF;
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

struct UHFArrays {
    uint256[] pubAssetIds;
    uint256[] pubValues;
    uint256[] nullifiers;
    uint256[] commitments;
    uint256[] encryptedDataEncryptionKeySeed;
    uint256[] refundInputs;
    uint256[][] notes;
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
    /// @custom:invariant ACCESS-4 Revoker must be active to be used in transaction
    /// @custom:invariant ADP-1: Adaptor should be supported by the protocol to be used in CALL_ADAPTOR transaction
    /// @custom:invariant STX-1: pubAssets length cannot exceed commitments length
    function validate(
        ShieldedTransaction calldata stx,
        MerkleTree storage addressTree,
        QueuedMerkleTree storage commitmentTree,
        address verifier,
        mapping(uint256 => uint32) storage markedNullifiers,
        mapping(address => bool) storage supportedAdaptors,
        mapping(uint256 => RevokerData) storage revokerDataMap
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

        if (stx.pubAssets.length > stx.commitments.length) {
            revert IPool.PubAssetsCannotExceedCommitments();
        }

        if (!verifyProof(stx, revokerData, verifier)) {
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

    function verifyProof(
        ShieldedTransaction calldata stx,
        RevokerData memory revokerData,
        address verifier
    ) public view returns (bool) {
        uint16 vId = IVerifier(verifier).getTransactionVerifierId(
            stx.nullifiers.length,
            stx.commitments.length
        );
        bytes memory vInp = toVerifierInput(stx, revokerData);
        return IVerifier(verifier).verifyTransactionProof(vId, vInp);
    }

    /**
     *
     * @param self ShieldedTransaction to convert to a proper verifier input
     * @param revokerData The RevokerData used for this transaction
     * @return Calldata bytes for appropriate verifier contract
     * @dev We divide the public inputs into 2 chunks to avoid stack too deep error
     */
    function toVerifierInput(
        ShieldedTransaction calldata self,
        RevokerData memory revokerData
    ) public pure returns (bytes memory) {
        bytes memory pubDataChunk1 = abi.encodePacked(
            self.addressTreeRoot,
            self.commitmentTreeRoot,
            hash(self),
            self.txType == ShieldedTransactionType.DEPOSIT
                ? uint256(0)
                : uint256(1)
        );

        bytes memory pubDataChunk2 = abi.encodePacked(
            revokerData.revokerPublicKey[0],
            revokerData.revokerPublicKey[1],
            self.refundAddress,
            revokerData.encryptionPublicKey[0],
            revokerData.encryptionPublicKey[1]
        );

        // Performing sequential hashing (sha256) of encrypted data derived from notesMemo
        (uint256 alpha, uint256 gamma) = _computeAlphaGammaForUHF(self);

        return
            abi.encodePacked(
                self.proof,
                pubDataChunk1,
                pubDataChunk2,
                alpha,
                self.betaUHF,
                gamma
            );
    }

    /// @dev Builds pubAsset/pubValue arrays padded to nOuts, then computes UHF (alpha, gamma).
    ///      Extracted to avoid stack-too-deep in toVerifierInput.
    function _computeAlphaGammaForUHF(
        ShieldedTransaction calldata self
    ) internal pure returns (uint256 alpha, uint256 gamma) {
        uint256 nOuts = self.commitments.length;
        uint256 nPubs = self.pubAssets.length;
        uint256[] memory pubAssetIds = new uint256[](nOuts);
        uint256[] memory pubValues = new uint256[](nOuts);

        for (uint256 i; i < nPubs; ++i) {
            pubAssetIds[i] = uint24(bytes3(bytes31(self.pubAssets[i])));
            pubValues[i] = uint224(self.pubAssets[i]);
        }
        // remaining entries are already zero-initialised

        UHFArrays memory uhfArrays = UHFArrays({
            pubAssetIds: pubAssetIds,
            pubValues: pubValues,
            nullifiers: self.nullifiers,
            commitments: self.commitments,
            encryptedDataEncryptionKeySeed: new uint256[](0),
            refundInputs: new uint256[](0),
            notes: new uint256[][](0)
        });
        (
            uhfArrays.encryptedDataEncryptionKeySeed,
            uhfArrays.refundInputs,
            uhfArrays.notes
        ) = _decomposeNotesMemo(self.notesMemo, nOuts);

        return _UHF(self.betaUHF, uhfArrays);
    }

    /**
        function genEncryptDataHashUsingPoseidon(
            bytes calldata notesMemo,
            uint256 nOuts,
            address hasher
        ) public view returns (uint256) {
            uint256 encryptedDataHash;

            // Call _decomposeNotesMemo() to get the uhfArrays
            (
                uint256[] memory encryptedDataEncryptionKeySeed,
                uint256[] memory refundInputs,
                uint256[][] memory notes
            ) = _decomposeNotesMemo(notesMemo, nOuts);
            // Hash encryptedDataEncryptionKeySeed (first 3 values)
            uint256 keySeedHash = IHasher(hasher).hash(
                encryptedDataEncryptionKeySeed
            ); // 3
            console.log("Encrypted DEK seed hash:");
            console.logUint(keySeedHash);

            // 3. Hash encryptedRefundData (next 4 values)
            uint256 refundHash = IHasher(hasher).hash(refundInputs); // 4
            console.log("Encrypted refund data hash:");
            console.logUint(refundHash);

            // 4. Hash each encryptedNote (4 values each)
            uint256[] memory noteHashes = new uint256[](nOuts);
            for (uint256 i = 0; i < nOuts; i++) {
                uint256[] memory noteInputs = new uint256[](4);
                for (uint256 j = 0; j < 4; j++) {
                    noteInputs[j] = notes[i][j];
                }
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
            return encryptedDataHash;
        }
     */

    ///////////////////////////////////
    ///////// Internal Functions //////
    ///////////////////////////////////

    function _decomposeNotesMemo(
        bytes calldata notesMemo,
        uint256 nOuts
    )
        internal
        pure
        returns (
            uint256[] memory encryptedDataEncryptionKeySeed,
            uint256[] memory refundInputs,
            uint256[][] memory notes
        )
    {
        require(notesMemo.length % 32 == 0, "Invalid notesMemo length");

        // 1. Split notesMemo into values array each 32 bytes
        uint256[] memory values = new uint256[](notesMemo.length / 32);
        for (uint256 i = 0; i < notesMemo.length / 32; i++) {
            values[i] = uint256(bytes32(notesMemo[i * 32:(i + 1) * 32]));
        }

        // 2. Hash encryptedDataEncryptionKeySeed (first 3 values)
        encryptedDataEncryptionKeySeed = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            encryptedDataEncryptionKeySeed[i] = values[i];
        }

        // 3. Hash encryptedRefundData (next 4 values)
        refundInputs = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            refundInputs[i] = values[i + 3];
        }

        // 4. Hash each encryptedNote (4 values each)
        notes = new uint256[][](nOuts);
        for (uint256 i = 0; i < nOuts; i++) {
            notes[i] = new uint256[](4);
            for (uint256 j = 0; j < 4; j++) {
                notes[i][j] = values[7 + (i * 4) + j];
            }
        }

        for (uint256 i = 0; i < nOuts; i++) {
            for (uint256 j = 0; j < 4; j++) {
                notes[i][j] = values[7 + (i * 4) + j];
            }
        }
    }

    /// @dev Performs sequential hashing (sha256) to generate `alpha` for _UHF
    function _genEncryptedDataHashUsingSha256(
        UHFArrays memory uhfArrays
    ) internal pure returns (uint256) {
        // Call _decomposeNotesMemo() to get the uhfArrays
        uint256 currentHash = 0;
        if (uhfArrays.pubAssetIds.length != 0) {
            currentHash = _hashChunkUsingSha256(
                currentHash,
                uhfArrays.pubAssetIds
            );

            currentHash = _hashChunkUsingSha256(
                currentHash,
                uhfArrays.pubValues
            );
        }

        currentHash = _hashChunkUsingSha256(currentHash, uhfArrays.nullifiers);

        currentHash = _hashChunkUsingSha256(currentHash, uhfArrays.commitments);

        currentHash = _hashChunkUsingSha256(
            currentHash,
            uhfArrays.encryptedDataEncryptionKeySeed
        );

        currentHash = _hashChunkUsingSha256(
            currentHash,
            uhfArrays.refundInputs
        );

        // Hash note data in chunks of 4
        for (uint i = 0; i < uhfArrays.notes.length; i++) {
            require(uhfArrays.notes[i].length == 4, "Invalid note data length");
            currentHash = _hashChunkUsingSha256(
                currentHash,
                uhfArrays.notes[i]
            );
        }
        return currentHash;
    }

    // Hashes a chunk of data with a previous hash value
    function _hashChunkUsingSha256(
        uint256 prev,
        uint256[] memory nums
    ) internal pure returns (uint256) {
        // Convert to bytes
        bytes memory data = abi.encodePacked(prev);
        for (uint i = 0; i < nums.length; i++) {
            data = abi.encodePacked(data, nums[i]);
        }

        bytes32 chunkHash = sha256(data);
        uint256 hashWithinField = uint256(chunkHash) % FIELD_SIZE;
        return hashWithinField;
    }

    function _addToUHFAccumulator(
        uint256[] memory elements,
        uint256 alpha,
        uint256 beta,
        uint256 coefficientPow,
        uint256 accumulator
    ) internal pure returns (uint256, uint256) {
        for (uint i = 0; i < elements.length; i++) {
            uint256 product = mulmod(elements[i], coefficientPow, FIELD_SIZE);
            accumulator = addmod(accumulator, product, FIELD_SIZE);
            coefficientPow = mulmod(coefficientPow, (alpha + beta), FIELD_SIZE);
        }
        return (accumulator, coefficientPow);
    }

    /// @dev Universal Hash Function (UHF) for reducing the encryted data public inputs (nIns + nOuts + 3 + 4 + nOuts * 4) to only 2 public inputs. This is done to reduce the number of public inputs to the circuit and be compatible with Nebra's requirement of a max of 16 PIs.
    /// @dev The UHF is defined as follows:
    // β (accumulator) = UHF(D, a) = ∑i a^i⋅Di modp where D = [D1, D2, ..., Dn] is the list of encrypted data private inputs and a is the alpha value and p is the prime field modulus.
    /// @dev The onchain implementation of UHF processes each array of inputs being hashed seperately (unlike the TS implementation), due to the stack size limit of 16 in Solidity.
    /// @param betaUHF This is the beta value for UHF which is generated from PoseidonEncryption of encryptedInputs offchain. This is passed in as a parameter to save gas instead of recomputing it onchain.
    function _UHF(
        uint256 betaUHF,
        UHFArrays memory uhfArrays
    ) internal pure returns (uint256, uint256) {
        uint256 alpha = _genEncryptedDataHashUsingSha256(uhfArrays);

        uint256 coefficientPow = 1;
        uint256 accumulator = 0;

        (accumulator, coefficientPow) = _addToUHFAccumulator(
            uhfArrays.pubAssetIds,
            alpha,
            betaUHF,
            coefficientPow,
            accumulator
        );

        (accumulator, coefficientPow) = _addToUHFAccumulator(
            uhfArrays.pubValues,
            alpha,
            betaUHF,
            coefficientPow,
            accumulator
        );

        (accumulator, coefficientPow) = _addToUHFAccumulator(
            uhfArrays.nullifiers,
            alpha,
            betaUHF,
            coefficientPow,
            accumulator
        );

        (accumulator, coefficientPow) = _addToUHFAccumulator(
            uhfArrays.commitments,
            alpha,
            betaUHF,
            coefficientPow,
            accumulator
        );

        (accumulator, coefficientPow) = _addToUHFAccumulator(
            uhfArrays.encryptedDataEncryptionKeySeed,
            alpha,
            betaUHF,
            coefficientPow,
            accumulator
        );

        (accumulator, coefficientPow) = _addToUHFAccumulator(
            uhfArrays.refundInputs,
            alpha,
            betaUHF,
            coefficientPow,
            accumulator
        );

        // Process individual notes
        for (uint i = 0; i < uhfArrays.commitments.length; i++) {
            (accumulator, coefficientPow) = _addToUHFAccumulator(
                uhfArrays.notes[i],
                alpha,
                betaUHF,
                coefficientPow,
                accumulator
            );
        }

        return (alpha, accumulator);
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

        for (uint256 i = 0; i < outLen; ++i) {
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
            // All fee goes to the paymaster only
            paymasterFees[params.paymaster][params.feeAssetId] += feeValue;
        }
    }

    function _receivePubAssets(
        mapping(uint24 => Asset) storage assets,
        PubAsset[] memory pubAssets,
        address from
    ) internal {
        uint256 count = pubAssets.length;

        for (uint256 i = 0; i < count; ) {
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
        for (uint256 i = 0; i < count; ) {
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

    /// @notice Marks nullifiers to prevent double-spending
    /// @param stx The shielded transaction containing nullifiers
    /// @custom:invariant NULL-1: Each nullifier can only be marked once per lifetime
    /// @custom:invariant NULL-2: markedNullifiers[n] = 0 means nullifier is unused
    /// @custom:invariant NULL-3: markedNullifiers[n] = nextIdx + 1 (never 0 for marked)
    function _checkAndMarkNullifiers(
        ShieldedTransaction calldata stx,
        QueuedMerkleTree storage commitmentTree,
        mapping(uint256 => uint32) storage markedNullifiers
    ) internal {
        uint256 numNullifiers = stx.nullifiers.length;
        uint32 nextIdx = commitmentTree.nextLeafIndex;

        for (uint256 i = 0; i < numNullifiers; ) {
            uint256 nullifier = stx.nullifiers[i];
            if (markedNullifiers[nullifier] != 0) {
                revert IPool.DoubleSpend(nullifier);
            }

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

        for (uint256 i = 0; i < memoParams.commitments.length; ++i) {
            uint32 leafIndex = leafIndexOffset + uint32(i);
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
            // FeeData is packed as follows:
            // 20 bytes - paymaster address
            // 3 bytes - feeAssetId (24 bits)
            // 9 bytes - feeValue (72 bits)

            // Extracting the paymaster address (20 bytes)
            params.paymaster = address(uint160(stx.feeData >> (24 + 72)));

            // Extract the feeAssetId (3 bytes)
            params.feeAssetId = uint24(stx.feeData >> 72);

            // Extract the feeValue (9 bytes)
            params.feeValue = uint72(stx.feeData);
        }

        params.pubAssets = new PubAsset[](pubLen);
        for (uint256 i = 0; i < pubLen; ++i) {
            // Extract first 3 bytes assetId
            params.pubAssets[i].id = uint24(bytes3(bytes31(stx.pubAssets[i])));
            // Extract last 28 bytes value
            params.pubAssets[i].value = uint224(stx.pubAssets[i]);

            /// Since feeAsset pushed into pubAssets, for transfer tx, the pubAssets value will become 0, but thats fine as pubAssets is not used in transfer tx. Only used in other types tx to move assets.
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
        for (uint256 i = 0; i < a.length; ) {
            result[i] = a[i];
            unchecked {
                ++i;
            }
        }
        for (uint256 i = 0; i < b.length; ) {
            result[a.length + i] = b[i];
            unchecked {
                ++i;
            }
        }
        return result;
    }
}
