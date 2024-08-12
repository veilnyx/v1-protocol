// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IHasher} from "../interfaces/IHasher.sol";
import {FIELD_SIZE, ZERO_LEAF} from "../base/Constants.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";

struct QueuedMerkleTree {
    uint8 depth;
    uint8 currentRootIndex;
    uint32 nextLeafIndex;
    uint40 capacity;
    address hasher;
    uint8 queueSize;
    address verifier;
    uint32 queuedLeavesLength;
    mapping(uint32 => uint256) queuedLeaves;
    mapping(uint8 => uint256) roots;
    mapping(uint8 => uint256) zeroes;
    mapping(uint8 => uint256) lastSubtrees;
}

struct SubtreeUpdateInputs {
    uint256 newRoot;
    uint256[] newSubtrees;
    bytes subtreeUpdateProof;
}

library QueuedMerkleTreeLogic {
    error MerkleTreeFull();

    uint8 public constant ROOT_HISTORY_SIZE = 100;

    function init(
        QueuedMerkleTree storage self,
        uint8 depth,
        address hasher,
        address verifier
    ) public {
        self.depth = depth;
        self.hasher = hasher;
        self.verifier = verifier;
        self.capacity = uint32(2 ** depth);
        self.queueSize = self.queueSize;

        uint256 zero = ZERO_LEAF;
        for (uint8 i = 0; i < depth; ) {
            self.zeroes[i] = zero;
            self.lastSubtrees[i] = zero;
            zero = IHasher(hasher).hash([zero, zero]);

            unchecked {
                ++i;
            }
        }

        self.roots[0] = zero;
    }

    function queueLeaves(
        QueuedMerkleTree storage self,
        uint256[] calldata leaves
    ) public {
        for (uint8 i = 0; i < leaves.length; ) {
            self.queuedLeaves[self.queuedLeavesLength] = leaves[i];
            self.queuedLeavesLength++;
            unchecked {
                ++i;
            }
        }
    }

    function updateSubtree(
        QueuedMerkleTree storage self,
        SubtreeUpdateInputs memory subtreeUpdateInputs
    ) public returns (uint256) {
        bool subtreeUpdateProofVerification = _verifySubtreeUpdateProof(
            self,
            subtreeUpdateInputs
        );

        if (subtreeUpdateProofVerification) {
            // updating roots
            uint8 newRootIndex = (self.currentRootIndex + 1) %
                ROOT_HISTORY_SIZE;
            self.roots[newRootIndex] = subtreeUpdateInputs.newRoot;

            // updating lastSubtrees
            for (uint8 i = 0; i < self.depth; ) {
                self.lastSubtrees[i] = subtreeUpdateInputs.newSubtrees[i];
                unchecked {
                    ++i;
                }
            }

            // updating nextLeafIndex
            self.nextLeafIndex += self.queueSize;

            // Emitting commitments after commitment leaves have been inserted into the commitment tree
            /// @todo move this to pool contract
            /// @notice not moving this to Pool as we are removing the leaves that got inserted from the queue, below. Since leaves are not persistent, they won't be accessible in Pool.sol for being emitted.
            for (uint8 i; i < self.queueSize; ) {
                emit IPool.Commitment(
                    self.nextLeafIndex - self.queueSize + i,
                    self.queuedLeaves[i]
                );

                unchecked {
                    ++i;
                }
            }

            // remove the inserted leaves from the queue
            for (uint8 i; i < self.queuedLeavesLength; ) {
                uint8 repositionQueueIndex = self.queueSize + i;

                if (repositionQueueIndex < self.queuedLeavesLength) {
                    self.queuedLeaves[i] = self.queuedLeaves[
                        repositionQueueIndex
                    ];
                }

                unchecked {
                    ++i;
                }
            }

            self.queuedLeavesLength -= self.queueSize;
        } else {
            revert IPool.InvalidSubtreeUpdateProof();
        }

        return self.nextLeafIndex;
    }

    function _verifySubtreeUpdateProof(
        QueuedMerkleTree storage self,
        SubtreeUpdateInputs memory subtreeUpdateInputs
    ) internal view returns (bool) {
        uint256[] memory leavesQueueForVerification = new uint256[](
            self.queueSize
        );
        uint256[] memory lastSubtreesArrayForVerification = new uint256[](self.depth);

        // converting `queueLeaves` mapping into array for verifier input
        // if `queueLeaves` mapping has elements less than `self.queueSize`, we add rest of element as zero values.
        for (uint8 i; i < self.queueSize; ) {
            if (self.queuedLeaves[i] != 0) {
                leavesQueueForVerification[i] = self.queuedLeaves[i];
            } else {
                leavesQueueForVerification[i] = 0;
            }

            unchecked {
                ++i;
            }
        }

        // converting mapping into array for verifier input
        for(uint8 i; i < self.depth; ) {
            lastSubtreesArrayForVerification[i] = self.lastSubtrees[i];

            unchecked{
                ++i;
            }
        }

        bytes memory vInp = abi.encodePacked(
            subtreeUpdateInputs.subtreeUpdateProof,
            self.nextLeafIndex,
            leavesQueueForVerification,
            self.roots[self.currentRootIndex],
            lastSubtreesArrayForVerification,
            subtreeUpdateInputs.newRoot,
            subtreeUpdateInputs.newSubtrees
        );
        bool subtreeVerificationResult = IVerifier(self.verifier)
            .verifySubtreeUpdateProof(vInp);

        return subtreeVerificationResult;
    }

    function isKnownRoot(
        QueuedMerkleTree storage self,
        uint256 _root
    ) public view returns (bool) {
        if (_root == 0) {
            return false;
        }
        uint8 _currentRootIndex = self.currentRootIndex;
        uint8 i = _currentRootIndex; // currentRootIndex -> 0
        do {
            if (_root == self.roots[i]) {
                return true;
            }
            if (i == 0) {
                // ROOT_HISTORY_SIZE -> currentRootIndex + 1
                i = ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    function getRoot(
        QueuedMerkleTree storage self,
        uint8 rootIndex
    ) external view returns (uint256) {
        return self.roots[rootIndex];
    }
}
