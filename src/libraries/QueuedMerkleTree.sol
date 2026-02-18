// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {FIELD_SIZE, ZERO_LEAF} from "../base/Constants.sol";
import {IHasher} from "../interfaces/IHasher.sol";
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
    uint32 queueStartIndex;
    uint32 queueEndIndex;
    mapping(uint32 => uint256) queuedLeaves;
    mapping(uint8 => uint256) roots;
    mapping(uint8 => uint256) zeroes;
    mapping(uint8 => uint256) lastSubtrees;
}

struct TreeUpdateData {
    uint256 newRoot;
    uint256[] newSubtrees;
    bytes proof;
}

library QueuedMerkleTreeLogic {
    error MerkleTreeFull();
    error InvalidProof();

    uint8 public constant ROOT_HISTORY_SIZE = 50;

    /// @custom:invariant QMT-1: queueStartIndex <= queueEndIndex always
    /// @custom:invariant QMT-2: queueEndIndex - queueStartIndex <= total leaves queued at all times
    function init(
        QueuedMerkleTree storage self,
        uint8 depth,
        uint8 queueSize,
        address hasher,
        address verifier
    ) public {
        self.depth = depth;
        self.hasher = hasher;
        self.verifier = verifier;
        self.capacity = uint32(2 ** depth);
        self.queueSize = queueSize;
        self.queueStartIndex = 0;
        self.queueEndIndex = 0;

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
        uint32 nextIndex = self.queueEndIndex;
        uint32 nLeaves = uint32(leaves.length);

        for (uint8 i = 0; i < nLeaves; ) {
            self.queuedLeaves[nextIndex + i] = leaves[i];
            unchecked {
                ++i;
            }
        }

        self.queueEndIndex += nLeaves;
    }

    function peekQueuedLeaves(
        QueuedMerkleTree storage self,
        uint32 n
    ) public view returns (uint256[] memory) {
        uint32 startIdx = self.queueStartIndex;
        uint32 endIdx = self.queueEndIndex;

        uint32 queueLen = endIdx - startIdx; //
        uint32 nLeaves = queueLen > n ? n : queueLen;

        uint256[] memory leaves = new uint256[](n);

        for (uint32 i = 0; i < nLeaves; ) {
            leaves[i] = self.queuedLeaves[startIdx + i];

            unchecked {
                ++i;
            }
        }

        if (nLeaves < n) {
            for (uint32 i = nLeaves; i < n; ) {
                leaves[i] = ZERO_LEAF;

                unchecked {
                    ++i;
                }
            }
        }

        return leaves;
    }

    /// @custom:invariant QMT-3: `nextLeafIndex` advances by exactly min(batchSize, queueSize) per update
    function update(
        QueuedMerkleTree storage self,
        TreeUpdateData calldata data
    ) public {
        uint32 batchSize = self.queueEndIndex - self.queueStartIndex;
        bool isValid = _verifyUpdateProof(self, data, batchSize);

        if (!isValid) {
            revert InvalidProof();
        }

        // Updating tree states
        uint8 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = data.newRoot;

        for (uint8 i = 0; i < self.depth; ) {
            self.lastSubtrees[i] = data.newSubtrees[i];
            unchecked {
                ++i;
            }
        }

        if (batchSize < self.queueSize) {
            self.queueStartIndex = self.queueEndIndex;
            self.nextLeafIndex += batchSize;
        } else {
            self.queueStartIndex += self.queueSize;
            self.nextLeafIndex += self.queueSize;
        }
    }

    function _verifyUpdateProof(
        QueuedMerkleTree storage self,
        TreeUpdateData calldata data,
        uint32 batchSize
    ) internal view returns (bool) {
        uint256[] memory leaves = _getQueuedLeaves(self);
        uint256[] memory lastSubtrees = _getSubtrees(self);
        uint256 lastRoot = self.roots[self.currentRootIndex];
        uint256 nZeroLeaves = batchSize < self.queueSize
            ? self.queueSize - batchSize
            : 0;

        bytes memory vParams = abi.encodePacked(
            data.proof,
            uint256(self.nextLeafIndex),
            leaves,
            lastRoot,
            lastSubtrees,
            data.newRoot,
            data.newSubtrees,
            nZeroLeaves
        );

        return IVerifier(self.verifier).verifyTreeUpdateProof(vParams);
    }

    function _getQueuedLeaves(
        QueuedMerkleTree storage tree
    ) internal view returns (uint256[] memory) {
        uint32 nLeaves = tree.queueSize;
        uint256[] memory leaves = peekQueuedLeaves(tree, nLeaves);
        return leaves;
    }

    function getQueuedLeaves(
        QueuedMerkleTree storage tree
    ) external view returns (uint256[] memory) {
        return _getQueuedLeaves(tree);
    }

    function _getSubtrees(
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

    /**
    function getRoot(
        QueuedMerkleTree storage self,
        uint8 rootIndex
    ) external view returns (uint256) {
        return self.roots[rootIndex];
    }
     */

    function getState(
        QueuedMerkleTree storage self
    )
        public
        view
        returns (uint256[] memory, uint256[] memory, uint256, uint8, uint32)
    {
        uint256[] memory leaves = _getQueuedLeaves(self);
        uint256[] memory lastSubtrees = _getSubtrees(self);
        uint32 nextLeafIndex = self.nextLeafIndex;
        uint256 lastRoot = self.roots[self.currentRootIndex];
        return (
            leaves,
            lastSubtrees,
            lastRoot,
            self.currentRootIndex,
            nextLeafIndex
        );
    }
}
