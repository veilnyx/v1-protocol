// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";

uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

enum ZTransactionType {
    DEPOSIT,
    TRANSFER,
    WITHDRAW,
    CONVERT,
    FUND
}

struct ZTransaction {
    ZTransactionType txType;
    uint256[8] proof;
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
    uint256[2] ephPubKey;
    uint256[] encAssets;
}

library ZTransactionLogic {
    uint256 constant ENC_PUB_KEY_X =
        5299619240641551281634865583518297030282874472190772894086521144482721001553;
    uint256 constant ENC_PUB_KEY_Y =
        16950150798460657717958625567821834550301663161624707787222815936182638968203;

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
        bytes4 selector
    ) public pure returns (bytes memory) {
        uint256 nIns = self.nullifiers.length;
        uint256 nOuts = self.commitments.length;
        uint256 nPubs = self.pubAssetIds.length;
        uint256 pubInputCount = 7 + nIns + (4 * nOuts);

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

        // Compliance ephemeral key: (Index: (3 + nIns + 3 * nOuts) to (5 + nIns + 3 * nOuts))
        pubInputs[3 + nIns + 3 * nOuts] = self.ephPubKey[0];
        pubInputs[3 + nIns + 3 * nOuts + 1] = self.ephPubKey[1];

        // Compliance encryption key: (Index: (5 + nIns + 3 * nOuts) to (7 + nIns + 3 * nOuts))
        pubInputs[3 + nIns + 3 * nOuts + 2] = ENC_PUB_KEY_X;
        pubInputs[3 + nIns + 3 * nOuts + 3] = ENC_PUB_KEY_Y;

        // Encrypted assets: (Index: (7 + nIns + 3 * nOuts) to (7 + nIns + 4 * nOuts))
        for (uint8 i = 0; i < nOuts; ) {
            pubInputs[7 + nIns + 3 * nOuts + i] = self.encAssets[i];
            unchecked {
                ++i;
            }
        }

        uint256[2] memory proofA = [self.proof[0], self.proof[1]];
        uint256[2][2] memory proofB = [
            [self.proof[2], self.proof[3]],
            [self.proof[4], self.proof[5]]
        ];
        uint256[2] memory proofC = [self.proof[6], self.proof[7]];

        bytes memory encodedProof = abi.encode(proofA, proofB, proofC);
        bytes memory packdPubInp = toPackedPubInp(pubInputs);
        bytes memory data = bytes.concat(selector, encodedProof, packdPubInp);

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
