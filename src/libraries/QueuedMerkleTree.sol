// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {ZERO_LEAF} from "../base/Constants.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";
import {LevelData} from "./MerkleTree.sol";

struct QueuedMerkleTree {
    uint8 depth;
    uint8 currentRootIndex;
    uint8 queueSize; // max number of leaves that can be queued before an update is required. This is defined by the circuit `treeUpdate::nLeaves` and is immutable after pool initialization.
    uint32 capacity;
    IHasher hasher;
    IVerifier verifier;
    uint32 nextLeafIndex;
    uint32 queueStartIndex;
    uint32 queueEndIndex;
    mapping(uint32 => uint256) queuedLeaves;
    mapping(uint8 => uint256) roots;
    mapping(uint8 => LevelData) levels;
}

struct TreeUpdateData {
    uint256 newRoot;
    uint32 batchSize;
    uint256[] newSubtrees;
    bytes proof;
}

library QueuedMerkleTreeLogic {
    error MerkleTreeFull();
    error InvalidProof();
    error InvalidDepth(uint8 depth, uint8 min, uint8 max);
    error ZeroAddress();

    uint8 internal constant ROOT_HISTORY_SIZE = 50;

    /// @custom:invariant QMT-1: queueStartIndex <= queueEndIndex always
    /// @custom:invariant QMT-2: queueEndIndex - queueStartIndex <= total leaves queued at all times
    function init(
        QueuedMerkleTree storage self,
        uint8 depth,
        uint8 queueSize,
        IHasher hasher,
        IVerifier verifier
    ) public {
        if (depth == 0 || depth > 31) {
            revert InvalidDepth(depth, 1, 31);
        }

        if (address(hasher) == address(0) || address(verifier) == address(0)) {
            revert ZeroAddress();
        }

        self.depth = depth;
        self.hasher = hasher;
        self.verifier = verifier;
        self.capacity = uint32(1 << depth);
        self.queueSize = queueSize;
        self.queueStartIndex = 0;
        self.queueEndIndex = 0;

        uint256 zero = ZERO_LEAF;
        for (uint8 i = 0; i < depth; ) {
            self.levels[i].zero = zero;
            self.levels[i].lastSubtree = zero;
            zero = hasher.hash([zero, zero]);

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

        for (uint32 i = 0; i < nLeaves; ) {
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

        uint32 batchSize = endIdx - startIdx;
        uint32 nLeaves = batchSize > n ? n : batchSize;

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
        (bool isValid, uint32 insertedLeaves) = _verifyUpdateProof(self, data);

        if (!isValid) {
            revert InvalidProof();
        }

        // Updating tree states
        uint8 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = data.newRoot;

        for (uint8 i = 0; i < self.depth; ) {
            self.levels[i].lastSubtree = data.newSubtrees[i];
            unchecked {
                ++i;
            }
        }

        if (data.batchSize < self.queueSize) {
            self.queueStartIndex = self.queueEndIndex;
        } else {
            self.queueStartIndex += insertedLeaves;
        }
        self.nextLeafIndex += insertedLeaves;
    }

    function _verifyUpdateProof(
        QueuedMerkleTree storage self,
        TreeUpdateData calldata data
    ) internal view returns (bool valid, uint32 insertedLeaves) {
        insertedLeaves = data.batchSize < self.queueSize
            ? data.batchSize
            : self.queueSize;
        uint256[] memory leaves = _getQueuedLeaves(self);
        uint256[] memory lastSubtrees = _getSubtrees(self);
        uint256 lastRoot = self.roots[self.currentRootIndex];
        uint256 nZeroLeaves = data.batchSize < self.queueSize
            ? self.queueSize - data.batchSize
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

        valid = self.verifier.verifyTreeUpdateProof(vParams);
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
            subtree[i] = tree.levels[i].lastSubtree;

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

    function getState(
        QueuedMerkleTree storage self
    )
        public
        view
        returns (
            uint256[] memory queuedLeaves,
            uint256[] memory subtrees,
            uint256 lastRoot,
            uint8 currentRootIdx,
            uint32 nextLeafIndex
        )
    {
        queuedLeaves = _getQueuedLeaves(self);
        subtrees = _getSubtrees(self);
        nextLeafIndex = self.nextLeafIndex;
        lastRoot = self.roots[self.currentRootIndex];
        currentRootIdx = self.currentRootIndex;
    }
}
