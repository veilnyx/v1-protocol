// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {FIELD_SIZE} from "../base/Constants.sol";
import {Asset, AssetLogic} from "./Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "./MerkleTree.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";

/// @title ZTransactionType enum representing types of shielded transactions
enum ZTransactionType {
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

/// @title ZTransaction struct representing shielded transaction
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
struct ZTransaction {
    ZTransactionType txType;
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
    ZTransactionType txType;
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
    /// @param ztx ZTransaction to be executed
    /// @param addressTree Address `MerkleTree` state in this contract
    /// @param commitmentTree Commitment `MerkleTree` state in this contract
    /// @param markedNullifiers Mapping of nullifiers that are already marked
    /// @param supportedAdaptors Mapping of supported external adaptor addresses
    function validate(
        ZTransaction calldata ztx,
        MerkleTree storage addressTree,
        MerkleTree storage commitmentTree,
        mapping(uint256 => uint32) storage markedNullifiers,
        mapping(address => bool) storage supportedAdaptors,
        mapping(uint256 => RevokerData) storage revokerDataMap,
        address verifier
    ) external {
        RevokerData memory revokerData = revokerDataMap[ztx.revokerId];

        if (!revokerData.isActive) {
            revert IPool.InvalidRevoker(ztx.revokerId);
        }

        if (!addressTree.isKnownRoot(ztx.addressTreeRoot)) {
            revert IPool.UnknownAddressTreeRoot();
        }

        if (!commitmentTree.isKnownRoot(ztx.commitmentTreeRoot)) {
            revert IPool.UnknownCommitmentTreeRoot();
        }

        if (
            ztx.txType == ZTransactionType.CALL_ADAPTOR &&
            !supportedAdaptors[address(bytes20(ztx.targetData))]
        ) {
            revert IPool.UnsupportedAdaptor();
        }

        _checkAndMarkNullifiers(ztx, commitmentTree, markedNullifiers);

        if (!_verifyProof(ztx, revokerData, verifier)) {
            revert IPool.InvalidTransactionProof();
        }
    }

    /// @notice Executes a shielded transaction
    /// @param ztx ZTransaction to be executed
    /// @param commitmentTree Commitment `MerkleTree` state in this contract
    /// @param assets Mapping of assetId to Asset
    /// @param adaptorHandler Address of the adaptor handler contract responsible for handling DeFi adaptor ops
    /// @param paymasterFees Mapping of paymaster address to assetId to fee value
    function execute(
        ZTransaction calldata ztx,
        MerkleTree storage commitmentTree,
        mapping(uint24 => Asset) storage assets,
        mapping(address => mapping(uint24 => uint256)) storage paymasterFees,
        mapping(uint24 => uint256) storage withdrawFees,
        address hasher,
        address adaptorHandler,
        uint256 withdrawFeeBps
    ) external {
        Params memory params = _copyParamsToMemory(ztx);
        MemoParams memory memoParams = _copyMemoParamsToMemory(ztx);

        // Credit paymaster fees
        _creditPaymasterFee(paymasterFees, params);

        // Receive any deposits
        if (ztx.txType == ZTransactionType.DEPOSIT) {
            _receivePubAssets(assets, params.pubAssets, msg.sender);
        }

        // Transfer any withdrawals
        if (ztx.txType == ZTransactionType.WITHDRAW) {
            _transferPubAssets(
                assets,
                withdrawFees,
                params.pubAssets,
                params.target,
                withdrawFeeBps
            );
        }

        // Perform any conversions
        if (ztx.txType == ZTransactionType.CALL_ADAPTOR) {
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
     * @param self ZTransaction to convert to a proper verifier input
     * @param revokerData The RevokerData used for this transaction
     * @return Calldata bytes for appropriate verifier contract
     * @dev We divide the public inputs into 2 chunks to avoid stack too deep error
     */
    function toVerifierInput(
        ZTransaction calldata self,
        RevokerData memory revokerData
    ) public pure returns (bytes memory) {
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
                self.txType == ZTransactionType.DEPOSIT
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
                revokerData.encryptionPublicKey[1],
                self.notesMemo
            );
        }

        bytes memory verifierParams = abi.encodePacked(
            self.proof,
            pubDataChunk1,
            pubDataChunk2
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

        /// @dev Creating commitments and output noteMemos for received tokens. This is done on the protocol side for CONVERT txns because the exact value of converted tokens can only be determined after executing the CONVERT tx.
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
        ZTransaction calldata ztx,
        RevokerData memory revokerData,
        address verifier
    ) internal view returns (bool) {
        uint16 vId = IVerifier(verifier).getTransactionVerifierId(
            ztx.nullifiers.length,
            ztx.commitments.length
        );
        bytes memory vInp = toVerifierInput(ztx, revokerData);
        return IVerifier(verifier).verifyTransactionProof(vId, vInp);
    }

    /// @dev This also prevents any duplicate nullifiers
    function _checkAndMarkNullifiers(
        ZTransaction calldata ztx,
        MerkleTree storage commitmentTree,
        mapping(uint256 => uint32) storage markedNullifiers
    ) internal {
        uint256 numNullifiers = ztx.nullifiers.length;
        uint32 nextIdx = commitmentTree.nextLeafIndex;

        for (uint8 i = 0; i < numNullifiers; ) {
            uint256 nullifier = ztx.nullifiers[i];
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
        MerkleTree storage tree,
        Params memory params,
        MemoParams memory memoParams
    ) internal {
        uint256 numCommitments = memoParams.commitments.length;
        uint256 nextIndex = MerkleTreeLogic.insert(
            tree,
            memoParams.commitments
        );

        for (uint8 i = 0; i < numCommitments; ++i) {
            emit IPool.Commitment(
                nextIndex - numCommitments + i,
                memoParams.commitments[i]
            );
        }

        emit IPool.Receipt(
            params.txType,
            params.revokerId,
            uint32(nextIndex - 1),
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
        ZTransaction calldata ztx
    ) internal pure returns (Params memory) {
        Params memory params;
        uint256 pubLen = ztx.pubAssets.length;

        params.pubAssets = new PubAsset[](pubLen);
        for (uint8 i = 0; i < pubLen; ++i) {
            // Extract first 3 bytes assetId
            params.pubAssets[i].id = uint24(bytes3(bytes31(ztx.pubAssets[i])));
            // Extract last 28 bytes value
            params.pubAssets[i].value = uint224(ztx.pubAssets[i]);
        }

        if (pubLen != 0) {
            params.feeAssetId = params.pubAssets[0].id;
            params.feeValue = uint96(ztx.feeData);
            params.paymaster = address(bytes20(bytes32(ztx.feeData)));
            params.pubAssets[0].value =
                params.pubAssets[0].value -
                params.feeValue;
        }

        params.txType = ztx.txType;
        params.revokerId = ztx.revokerId;
        params.target = address(bytes20(ztx.targetData));
        if (params.target != address(0)) {
            params.targetPayload = bytes(ztx.targetData[20:]);
        }

        if (ztx.txType == ZTransactionType.CALL_ADAPTOR) {
            params.refundAddress = ztx.refundAddress;
        }

        return params;
    }

    function _copyMemoParamsToMemory(
        ZTransaction calldata ztx
    ) internal pure returns (MemoParams memory) {
        MemoParams memory memoParams;

        memoParams.commitments = ztx.commitments;
        memoParams.keysMemo = ztx.keysMemo;
        memoParams.notesMemo = ztx.notesMemo;

        if (ztx.txType == ZTransactionType.TRANSFER) {
            memoParams.assetsMemo = ztx.assetsMemo;
        } else {
            memoParams.assetsMemo = abi.encodePacked(ztx.pubAssets);
        }

        if (ztx.txType == ZTransactionType.CALL_ADAPTOR) {
            memoParams.refundMemo = abi.encodePacked(ztx.refundAddress);
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
