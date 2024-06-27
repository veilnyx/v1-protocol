// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {PoseidonT4} from "poseidon-solidity/PoseidonT4.sol";
import {Asset, AssetLogic} from "src/libraries/Asset.sol";
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

    function execute(
        ZTransaction memory ztx,
        mapping(address => mapping(uint24 => uint256)) storage paymasterFees
    ) external {
        // Transfer any fees
        _transferFee(ztx, paymasterFees);
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

            // AssetLogic.transferAsset({
            //     assets: assets,
            //     to: paymaster,
            //     assetId: ztx.pubAssetIds[0],
            //     value: feeValue
            // });
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
}
