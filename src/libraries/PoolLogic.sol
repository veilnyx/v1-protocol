// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IConvertor} from "../interfaces/IConvertor.sol";
import {AssetLogic} from "../libraries/AssetLogic.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTreeLogic.sol";
import {Asset, AssetType, MemoType} from "../libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType} from "../libraries/ZTransaction.sol";
import {PoseidonT4} from "poseidon-solidity/PoseidonT4.sol";

import {console} from "forge-std/console.sol";

library PoolLogic {
    using MerkleTreeLogic for MerkleTree;

    function executeTransaction(
        MerkleTree storage tree,
        mapping(uint24 => Asset) storage assets,
        mapping(address => bool) storage supportedProxies,
        mapping(uint256 => bool) storage markedNullifiers,
        address verifier,
        address convertor,
        ZTransaction memory ztx
    ) external {
        _validateTransaction(
            tree,
            supportedProxies,
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
            _transferToExceptFee(
                assets,
                address(uint160(ztx.beneficiary)),
                ztx
            );
        }

        // Perform any conversions
        if (ztx.txType == ZTransactionType.CONVERT) {
            _transferToExceptFee(assets, convertor, ztx);
            _convert(assets, convertor, ztx);
        }

        _mintNotes(tree, ztx.commitments, ztx.memos);

        emit IPool.ComplianceMemo(ztx.complianceMemo);
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
            newMemos[i] = ztx.memos[i];

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
        ztx.memos = newMemos;
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

    // function _receiveDeposits(
    //     mapping(uint24 => Asset) storage assets,
    //     ZTransaction memory ztx
    // ) internal {
    //     uint256 pubAssetCount = ztx.pubAssetIds.length;

    //     for (uint8 i = 0; i < pubAssetCount; ) {
    //         AssetLogic.receiveAsset({
    //             assets: assets,
    //             from: msg.sender,
    //             assetId: ztx.pubAssetIds[i],
    //             value: ztx.pubValues[i]
    //         });

    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    function _validateTransaction(
        MerkleTree storage tree,
        mapping(address => bool) storage supportedProxies,
        mapping(uint256 => bool) storage markedNullifiers,
        address verifier,
        ZTransaction memory ztx
    ) internal {
        // Check recent merkle root
        if (!tree.isKnownRoot(ztx.merkleRoot, 100)) {
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
        bytes[] memory memos
    ) internal {
        uint256 nextIndex = MerkleTreeLogic.insert(tree, commitments);
        uint256 cmLen = commitments.length;

        for (uint256 i = 0; i < cmLen; ) {
            emit IPool.Announcement(
                nextIndex - cmLen + i,
                commitments[i],
                memos[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function addAssets(
        mapping(address => uint24) storage assetIds,
        mapping(uint24 => Asset) storage assets,
        uint16 counter,
        AssetType[] calldata assetTypes,
        address[] calldata assetAddresses
    ) external returns (uint16) {
        return
            AssetLogic.addAssets(
                assetIds,
                assets,
                counter,
                assetTypes,
                assetAddresses
            );
    }
}
