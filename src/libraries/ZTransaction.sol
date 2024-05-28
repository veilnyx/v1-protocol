// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {PoseidonT4} from "poseidon-solidity/PoseidonT4.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IConvertor} from "../interfaces/IConvertor.sol";
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

/// @title ZTransaction struct representing shielded transaction
///
/// @param txType           Type of transaction
/// @param proof            Abi encoded proof
/// @param merkleRoot       Recent merkle root of commitment tree
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
///                         a convert proxy address in case of `CONVERT` transaction
/// @param targetPayload    Payload for target contract (if applicable)
/// @param complianceMemo   Encrypted compliance data
struct ZTransaction {
    ZTransactionType txType;
    bytes proof;
    uint256 merkleRoot;
    // Public data
    uint24[] pubAssetIds; // First index is always fee asset
    uint256[] pubValues;
    // Notes info
    uint256[] nullifiers;
    uint256[] commitments;
    bytes inMemos;
    bytes[] outMemos;
    // Fees info
    uint256 feeData; // 20-byte address + 12-byte fee value
    uint256 beneficiary; // stealth address for any public fund to shielded account
    bytes beneficiaryMemo;
    address target;
    bytes targetPayload;
    // Compliance params
    bytes complianceMemo;
}

/// @title ZTransactionLogic library for shielded transaction logic
library ZTransactionLogic {
    using MerkleTreeLogic for MerkleTree;

    uint256 constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @notice Calculates the hash of a ZTransaction
    /// @param self ZTransaction
    /// @return Hash of the transaction
    function hash(ZTransaction memory self) public pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        self.txType,
                        self.merkleRoot,
                        self.pubAssetIds,
                        self.pubValues,
                        self.nullifiers,
                        self.commitments,
                        self.inMemos,
                        self.outMemos,
                        self.feeData,
                        self.beneficiary,
                        self.beneficiaryMemo,
                        self.target,
                        self.targetPayload
                    )
                )
            ) % FIELD_SIZE;
    }

    /// @notice Executes a shielded transaction
    /// @param ztx ZTransaction to be executed
    /// @param tree MerkleTree state in this contract
    /// @param assets Mapping of assetId to Asset
    /// @param convertProxies Mapping of convert proxy addresses
    /// @param markedNullifiers Mapping of nullifiers that are already marked
    /// @param verifier Verifier contract address
    /// @param convertor Convertor contract address
    function execute(
        ZTransaction memory ztx,
        MerkleTree storage tree,
        mapping(uint24 => Asset) storage assets,
        mapping(address => bool) storage convertProxies,
        mapping(uint256 => bool) storage markedNullifiers,
        address verifier,
        address convertor
    ) external {
        _validateTransaction(
            tree,
            convertProxies,
            markedNullifiers,
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
            _transferToExceptFee(assets, convertor, ztx);
            _convert(assets, convertor, ztx);
        }

        _mintNotes(tree, ztx.commitments, ztx.inMemos, ztx.outMemos);

        emit IPool.ComplianceMemo(ztx.complianceMemo);
    }

    /// @notice Calculates calldata to proper verifier contract
    /// @param self ZTransaction
    /// @param selector Selector of verifier contract
    /// @param encryptionPublicKeyX Compliance encryption public key x
    /// @param encryptionPublicKeyY Compliance encryption public key y
    /// @return Calldata bytes for verifier contract
    function toVerifierInput(
        ZTransaction memory self,
        bytes4 selector,
        uint256 encryptionPublicKeyX,
        uint256 encryptionPublicKeyY
    ) public pure returns (bytes memory) {
        uint256 nIns = self.nullifiers.length;
        uint256 nOuts = self.commitments.length;
        uint256 nPubs = self.pubAssetIds.length;
        uint256 pubInputCount = 10 + nIns + (6 * nOuts);

        uint256[] memory pubInputs = new uint256[](pubInputCount);

        // Common params (Index: 0 to 3)
        pubInputs[0] = self.merkleRoot;
        pubInputs[1] = hash(self);
        pubInputs[2] = self.txType == ZTransactionType.DEPOSIT ? 0 : 1;

        // Public asset ids and values (Index: 3 to 3 + 2 * nOuts)
        uint256 offset = 3;
        for (uint8 i = 0; i < nOuts; ) {
            pubInputs[offset + i] = i < nPubs ? self.pubAssetIds[i] : 0;
            pubInputs[offset + nOuts + i] = i < nPubs ? self.pubValues[i] : 0;
            unchecked {
                ++i;
            }
        }

        // Input notes nullifiers (Index: 3 + 2 * nOuts to (3 + nIns + 2 * nOuts))
        offset += 2 * nOuts;
        for (uint8 i = 0; i < nIns; ) {
            pubInputs[offset + i] = self.nullifiers[i];
            unchecked {
                ++i;
            }
        }

        // Output notes commitments: (Index: (3 + nIns + 2 * nOuts) to (3 + nIns + 3 * nOuts)
        offset += nIns;
        for (uint8 i = 0; i < nOuts; ) {
            pubInputs[offset + i] = self.commitments[i];
            unchecked {
                ++i;
            }
        }

        // Beneficiary stealth address (Index: (3 + nIns + 3 * nOuts) to (4 + nIns + 3 * nOuts))
        offset += nOuts;
        pubInputs[offset] = self.beneficiary;
        // Compliance encryption key: (Index: (4 + nIns + 3 * nOuts) to (6 + nIns + 3 * nOuts))
        pubInputs[offset + 1] = encryptionPublicKeyX;
        pubInputs[offset + 2] = encryptionPublicKeyY;

        // Compliance memo: (Index: (6 + nIns + 3 * nOuts) to (9 + nIns + 4 * nOuts))
        offset += 3;
        // [6 + nIns + 3 * nOuts]: ephemeral pub key x
        // [7 + nIns + 3 * nOuts]: ephemeral pub key y
        // [8 + nIns + 3 * nOuts]: encrypted in publicKeyX
        // [9 + nIns + 3 * nOuts]: encrypted beneficiary blinding
        // [9 + nIns + 3 * nOuts...9 + nIns + 4 * nOuts]: encrypted out assets
        // [9 + nIns + 4 * nOuts...9 + nIns + 5 * nOuts]: encrypted out blindings
        // [9 + nIns + 5 * nOuts...9 + nIns + 6 * nOuts]: encrypted out pubKeyXs
        bytes memory complianceMemo = self.complianceMemo;
        uint256 tmp;
        for (uint8 i = 0; i < 3 * nOuts + 4; ) {
            assembly {
                tmp := mload(add(complianceMemo, add(0x20, mul(0x20, i))))
            }
            pubInputs[offset + i] = tmp;
            unchecked {
                ++i;
            }
        }

        bytes memory packdPubInp = _packPubInputs(pubInputs);
        bytes memory data = bytes.concat(selector, self.proof, packdPubInp);

        return data;
    }

    function _convert(
        mapping(uint24 => Asset) storage assets,
        address convertor,
        ZTransaction memory ztx
    ) internal {
        (uint24[] memory outAssetIds, uint256[] memory outValues) = IConvertor(
            convertor
        ).convert(
                ztx.target,
                ztx.pubAssetIds,
                ztx.pubValues,
                ztx.targetPayload
            );

        _receiveAssetsFrom(assets, convertor, outAssetIds, outValues);

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
        uint256 firstValue = ztx.pubValues[0] - feeValue;

        if (firstValue != 0) {
            AssetLogic.transferAsset({
                assets: assets,
                to: to,
                assetId: ztx.pubAssetIds[0],
                value: firstValue
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
        MerkleTree storage tree,
        mapping(address => bool) storage supportedProxies,
        mapping(uint256 => bool) storage markedNullifiers,
        address verifier,
        ZTransaction memory ztx
    ) internal {
        // Check recent merkle root
        if (!tree.isKnownRoot(ztx.merkleRoot)) {
            revert IPool.UnknownMerkleRoot();
        }

        if (
            ztx.txType == ZTransactionType.CONVERT &&
            !supportedProxies[ztx.target]
        ) {
            revert IPool.UnsupportedProxy();
        }

        // Verify ZK proof
        if (!IVerifier(verifier).verifyTransactionProof(ztx)) {
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

    function _packPubInputs(
        uint256[] memory arr
    ) internal pure returns (bytes memory) {
        uint256 len = arr.length;
        bytes memory res = new bytes(32 * len);

        assembly {
            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 1)
            } {
                mstore(
                    add(res, mul(0x20, add(i, 1))),
                    mload(add(arr, mul(0x20, add(i, 1))))
                )
            }
        }

        return res;
    }
}
