// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {PoseidonT4} from "poseidon-solidity/PoseidonT4.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {FIELD_SIZE} from "../core/Constants.sol";
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
    uint248[] pubAssets; // (assetId + value)[]
    uint256[] nullifiers;
    uint256[] commitments;
    bytes proof;
    bytes[] noteMemos;
    bytes assetMemo;
    bytes complianceMemo;
    bytes targetData; // target address + payload
    bytes refundData; // refund address + memo
}

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
    bytes[] noteMemos;
    bytes complianceMemo;
    bytes assetMemo;
    bytes refundAddressMemo;
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
                    self.nullifiers,
                    self.noteMemos,
                    self.assetMemo,
                    self.targetData,
                    self.refundData
                )
            )
        ) % FIELD_SIZE;

        return txHash;
    }

    ///@notice Validates a shielded transaction
    /// @param ztx ZTransaction to be executed
    /// @param addressTree Address `MerkleTree` state in this contract
    /// @param commitmentTree Commitment `MerkleTree` state in this contract
    /// @param supportedAdaptors Mapping of supported external adaptor addresses
    /// @param markedNullifiers Mapping of nullifiers that are already marked
    function validate(
        ZTransaction calldata ztx,
        MerkleTree storage addressTree,
        MerkleTree storage commitmentTree,
        mapping(address => bool) storage supportedAdaptors,
        mapping(uint256 => bool) storage markedNullifiers,
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
        if (!_verifyProof(ztx, revokerData, verifier)) {
            revert IPool.InvalidProof();
        }

        // Check double spend and mark nullifiers
        _checkAndMarkNullifiers(markedNullifiers, ztx.nullifiers);
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
        address adaptorHandler
    ) external {
        Params memory params = _copyParamsToMemory(ztx);
        MemoParams memory memoParams = _copyMemoParamsToMemory(ztx);

        // Transfer paymaster fees
        _transferPaymasterFee(paymasterFees, params);

        // Receive any deposits
        if (ztx.txType == ZTransactionType.DEPOSIT) {
            _receivePubAssets(assets, params.pubAssets, msg.sender);
        }

        // Transfer any withdrawals
        if (ztx.txType == ZTransactionType.WITHDRAW) {
            _transferPubAssets(assets, params.pubAssets, params.target);
        }

        // Perform any conversions
        if (ztx.txType == ZTransactionType.CONVERT) {
            _transferPubAssets(assets, params.pubAssets, adaptorHandler);
            _handleAdaptor(assets, adaptorHandler, params, memoParams);
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
                bytes32(self.refundData),
                revokerData.encryptionPublicKey[0],
                revokerData.encryptionPublicKey[1],
                self.complianceMemo
            );
        }

        bytes memory verifierParams = abi.encodePacked(
            self.proof,
            pubDataChunk1,
            pubDataChunk2
        );

        return verifierParams;
    }

    function _handleAdaptor(
        mapping(uint24 => Asset) storage assets,
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

        uint256 outLen = outPubAssets.length;

        uint256[] memory pubCms = new uint256[](outLen);
        bytes[] memory pubMemos = new bytes[](outLen);

        for (uint8 i = 0; i < outLen; ++i) {
            pubCms[i] = PoseidonT4.hash(
                [
                    outPubAssets[i].id,
                    params.refundAddress,
                    outPubAssets[i].value
                ]
            );
            pubMemos[i] = abi.encodePacked(
                MemoType.SEMI,
                outPubAssets[i].id,
                params.refundAddress,
                outPubAssets[i].value,
                memoParams.refundAddressMemo
            );
        }

        memoParams.commitments = _concat(memoParams.commitments, pubCms);
        memoParams.noteMemos = _concat(memoParams.noteMemos, pubMemos);
    }

    function _transferPaymasterFee(
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
        PubAsset[] memory pubAssets,
        address to
    ) internal {
        uint256 count = pubAssets.length;

        for (uint8 i = 0; i < count; ) {
            AssetLogic.transferAsset({
                assets: assets,
                to: to,
                assetId: pubAssets[i].id,
                value: pubAssets[i].value
            });

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
        uint16 vId = IVerifier(verifier).getVerifierId(
            ztx.nullifiers.length,
            ztx.commitments.length
        );
        bytes memory vInp = toVerifierInput(ztx, revokerData);
        return IVerifier(verifier).verifyTransactionProof(vId, vInp);
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
            memoParams.assetMemo,
            memoParams.complianceMemo,
            memoParams.noteMemos
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

        if (ztx.txType == ZTransactionType.CONVERT) {
            params.refundAddress = uint256(bytes32(ztx.refundData));
        }

        return params;
    }

    function _copyMemoParamsToMemory(
        ZTransaction calldata ztx
    ) internal pure returns (MemoParams memory) {
        MemoParams memory memoParams;

        memoParams.commitments = ztx.commitments;
        memoParams.noteMemos = ztx.noteMemos;
        memoParams.complianceMemo = ztx.complianceMemo;

        if (ztx.txType == ZTransactionType.TRANSFER) {
            memoParams.assetMemo = ztx.assetMemo;
        } else {
            memoParams.assetMemo = abi.encodePacked(ztx.pubAssets);
        }

        if (ztx.txType == ZTransactionType.CONVERT) {
            memoParams.refundAddressMemo = ztx.refundData[32:];
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

    function _concat(
        bytes[] memory a,
        bytes[] memory b
    ) internal pure returns (bytes[] memory) {
        bytes[] memory result = new bytes[](a.length + b.length);
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
