// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

enum ZTransactionType {
    DEPOSIT,
    TRANSFER,
    WITHDRAW,
    CONVERT
}

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
    bytes[] memos;
    // Fees info
    uint256 feeData; // 20-byte address + 12-byte fee value
    uint256 beneficiary; // stealth address or normal address
    bytes beneficiaryMemo;
    address target;
    bytes targetPayload;
    // Compliance params
    bytes complianceMemo;
}

library ZTransactionLogic {
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
                        self.memos,
                        self.feeData,
                        self.beneficiary,
                        self.beneficiaryMemo,
                        self.target,
                        self.targetPayload
                    )
                )
            ) % FIELD_SIZE;
    }

    function toVerifierInput(
        ZTransaction memory self,
        bytes4 selector,
        uint256[2] memory encryptionPublicKey
    ) public pure returns (bytes memory) {
        uint256 nIns = self.nullifiers.length;
        uint256 nOuts = self.commitments.length;
        uint256 nPubs = self.pubAssetIds.length;
        uint256 pubInputCount = 7 + nIns + (6 * nOuts);

        uint256[] memory pubInputs = new uint256[](pubInputCount);

        // Common params (Index: 0 to 3)
        pubInputs[0] = self.merkleRoot;
        pubInputs[1] = hash(self);
        pubInputs[2] = self.txType == ZTransactionType.DEPOSIT ? 0 : 1;

        // Public asset ids and values (Index: 3 to 3 + 2 * nOuts)
        for (uint8 i = 0; i < nOuts; ) {
            pubInputs[3 + i] = i < nPubs ? self.pubAssetIds[i] : 0;
            pubInputs[3 + nOuts + i] = i < nPubs ? self.pubValues[i] : 0;
            unchecked {
                ++i;
            }
        }

        // Input notes nullifiers (Index: 3 + 2 * nOuts to (3 + nIns + 2 * nOuts))
        for (uint8 i = 0; i < nIns; ) {
            pubInputs[3 + (2 * nOuts) + i] = self.nullifiers[i];
            unchecked {
                ++i;
            }
        }

        // Output notes commitments: (Index: (3 + nIns + 2 * nOuts) to (3 + nIns + 3 * nOuts)
        for (uint8 i = 0; i < nOuts; ) {
            pubInputs[3 + nIns + (2 * nOuts) + i] = self.commitments[i];
            unchecked {
                ++i;
            }
        }

        // Compliance encryption key: (Index: (3 + nIns + 3 * nOuts) to (5 + nIns + 3 * nOuts))
        pubInputs[3 + nIns + 3 * nOuts] = encryptionPublicKey[0];
        pubInputs[4 + nIns + 3 * nOuts] = encryptionPublicKey[1];

        // Compliance memo: (Index: (5 + nIns + 3 * nOuts) to (9 + nIns + 4 * nOuts))
        // [5 + nIns + 3 * nOuts]: ephemeral pub key x
        // [6 + nIns + 3 * nOuts]: ephemeral pub key y
        // [7 + nIns + 3 * nOuts...7 + nIns + 4 * nOuts]: encrypted assets
        // [7 + nIns + 4 * nOuts...7 + nIns + 5 * nOuts]: encrypted blindings
        // [7 + nIns + 5 * nOuts...7 + nIns + 6 * nOuts]: encrypted pubKeyXs
        bytes memory complianceMemo = self.complianceMemo;
        uint256 tmp;
        for (uint8 i = 0; i < nOuts + 6; ) {
            assembly {
                tmp := mload(add(complianceMemo, add(0x20, mul(0x20, i))))
            }
            pubInputs[5 + nIns + 3 * nOuts + i] = tmp;
            unchecked {
                ++i;
            }
        }

        bytes memory packdPubInp = toPackedPubInp(pubInputs);
        bytes memory data = bytes.concat(selector, self.proof, packdPubInp);

        return data;
    }

    function toPackedPubInp(
        uint256[] memory arr
    ) public pure returns (bytes memory) {
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
