// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IHasher} from "../interfaces/IHasher.sol";
import {FIELD_SIZE, ZERO_LEAF} from "../base/Constants.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";

struct QueuedMerkleTree {
    uint8 depth;
    uint8 currentRootIndex;
    uint8 queueSize;
    uint40 capacity;
    address hasher;
    address verifier;
    uint32 nextLeafIndex;
    uint32 nextQueueIndex;
    mapping(uint32 => uint256) queuedLeaves;
    mapping(uint8 => uint256) roots;
    mapping(uint8 => uint256) zeroes;
    mapping(uint8 => uint256) lastSubtrees;
}

struct SubtreeUpdateData {
    uint256 newRoot;
    uint256[] newSubtrees;
    bytes proof;
}

library QueuedMerkleTreeLogic {
    error MerkleTreeFull();

    uint8 public constant ROOT_HISTORY_SIZE = 50;

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
        uint32 nextIndex = self.nextQueueIndex;
        uint32 nLeaves = uint32(leaves.length);

        for (uint8 i = 0; i < nLeaves; ) {
            self.queuedLeaves[nextIndex + i] = leaves[i];
            unchecked {
                ++i;
            }
        }

        self.nextQueueIndex = nextIndex + uint32(nLeaves);
    }

    function update(
        QueuedMerkleTree storage self,
        SubtreeUpdateData calldata data
    ) public returns (uint256) {
        bool isValid = _verifyUpdateProof(self, data);

        if (!isValid) {
            revert("Invalid proof");
        }

        uint8 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.roots[newRootIndex] = data.newRoot;

        for (uint8 i = 0; i < self.depth; ) {
            self.lastSubtrees[i] = data.newSubtrees[i];
            unchecked {
                ++i;
            }
        }

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

        return self.nextLeafIndex;
    }

    function _verifyUpdateProof(
        QueuedMerkleTree storage self,
        SubtreeUpdateData calldata data
    ) internal view returns (bool) {
        uint256[] memory leaves = _getQueuedLeaves(self);
        uint256[] memory lastSubtrees = _getSubtree(self);

        bytes memory vInp = abi.encodePacked(
            data.proof,
            self.nextLeafIndex,
            leaves,
            self.roots[self.currentRootIndex],
            lastSubtrees,
            data.newRoot,
            data.newSubtrees
        );

        return IVerifier(self.verifier).verifySubtreeUpdateProof(vInp);
    }

    function _getQueuedLeaves(
        QueuedMerkleTree storage tree
    ) internal view returns (uint256[] memory) {
        uint256[] memory leaves = new uint256[](tree.queueSize);
        uint32 startIdx = tree.nextLeafIndex;
        uint32 endIdx = startIdx + tree.queueSize;

        // Pad the queue with zeroes if queue is not full
        for (uint32 i = startIdx; i < endIdx; ) {
            if (i < tree.nextQueueIndex) {
                leaves[i] = tree.queuedLeaves[i];
            } else {
                leaves[i] = ZERO_LEAF;
            }

            unchecked {
                ++i;
            }
        }

        return leaves;
    }

    function _getSubtree(
        QueuedMerkleTree storage tree
    ) internal view returns (uint256[] memory) {
        uint256[] memory subtree = new uint256[](tree.depth);

        for (uint8 i; i < tree.depth; ) {
            subtree[i] = tree.lastSubtrees[i];

            unchecked {
                ++i;
            }
        }

        return subtree;
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

    function getState(
        QueuedMerkleTree storage self
    )
        public
        view
        returns (uint256[] memory, uint256[] memory, uint256, uint32)
    {
        uint256[] memory leaves = _getQueuedLeaves(self);
        uint256[] memory lastSubtrees = _getSubtree(self);
        uint32 nextLeafIndex = self.nextLeafIndex;
        uint256 lastRoot = self.roots[self.currentRootIndex];
        return (leaves, lastSubtrees, lastRoot, nextLeafIndex);
    }
}
