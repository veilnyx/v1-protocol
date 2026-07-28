// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {ZERO_LEAF, COMMITMENT_MERKLE_TREE_ROOT_HISTORY_SIZE, COMMITMENT_TREE_DEPTH, TREE_UPDATE_QUEUE_SIZE} from "../base/Constants.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";

struct QueuedMerkleTree {
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
    uint256[COMMITMENT_TREE_DEPTH] levelZeros;
    uint256[COMMITMENT_TREE_DEPTH] levelSubtrees;
}

struct TreeUpdateData {
    uint256 newRoot;
    uint32 batchSize;
    uint256[COMMITMENT_TREE_DEPTH] newLevelSubtrees;
    bytes proof;
}

library QueuedMerkleTreeLogic {
    error MerkleTreeFull();
    error InvalidProof();
    error InvalidBatchSize();
    error InvalidQueueSize(uint8 given, uint8 expected);
    error ZeroAddress();

    /// @custom:invariant QMT-1: queueStartIndex <= queueEndIndex always
    /// @custom:invariant QMT-2: queueEndIndex - queueStartIndex <= total leaves queued at all times
    function init(
        QueuedMerkleTree storage self,
        uint8 queueSize,
        IHasher hasher,
        IVerifier verifier
    ) public {
        if (address(hasher) == address(0) || address(verifier) == address(0)) {
            revert ZeroAddress();
        }

        // The treeUpdate circuit is compiled as TreeUpdate(COMMITMENT_TREE_DEPTH, 10),
        // so its public-input count -- and therefore the verifier calldata layout --
        // is fixed at this queue size. Any other value would silently produce
        // vParams of the wrong length and make every tree update revert, halting
        // commitment insertion permanently.
        if (queueSize != TREE_UPDATE_QUEUE_SIZE) {
            revert InvalidQueueSize(queueSize, TREE_UPDATE_QUEUE_SIZE);
        }

        self.hasher = hasher;
        self.verifier = verifier;
        self.capacity = uint32(1 << COMMITMENT_TREE_DEPTH);
        self.queueSize = queueSize;
        self.queueStartIndex = 0;
        self.queueEndIndex = 0;

        uint256 zero = ZERO_LEAF;
        for (uint8 i = 0; i < COMMITMENT_TREE_DEPTH; ) {
            self.levelZeros[i] = zero;
            self.levelSubtrees[i] = zero;
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

        for (uint32 i = nLeaves; i < n; ) {
            leaves[i] = ZERO_LEAF;

            unchecked {
                ++i;
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
        uint8 newRootIndex = (self.currentRootIndex + 1) %
            COMMITMENT_MERKLE_TREE_ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = data.newRoot;
        self.levelSubtrees = data.newLevelSubtrees;

        // `insertedLeaves` is min(pending, queueSize) by construction, so this can never
        // advance past `queueEndIndex`.
        self.queueStartIndex += insertedLeaves;
        self.nextLeafIndex += insertedLeaves;
    }

    function _verifyUpdateProof(
        QueuedMerkleTree storage self,
        TreeUpdateData calldata data
    ) internal view returns (bool valid, uint32 insertedLeaves) {
        // Derive the batch size from queue state rather than trusting the caller.
        // `batchSize` only reaches the circuit as `nZeroLeaves`, and padding an empty
        // slot with ZERO_LEAF is a root no-op, so an OVERSTATED batchSize is honestly
        // provable while advancing `queueStartIndex` past `queueEndIndex`. Every later
        // `queueEndIndex - queueStartIndex` would then underflow and revert, including
        // the one on the transact path, permanently bricking the pool.
        uint32 pending = self.queueEndIndex - self.queueStartIndex;
        insertedLeaves = pending < self.queueSize ? pending : self.queueSize;

        // Kept as a caller-supplied field for ABI compatibility, but it must agree with
        // the state-derived value; otherwise the proof was generated for a different
        // nZeroLeaves and would fail verification with a far less obvious error.
        if (data.batchSize != insertedLeaves) {
            revert InvalidBatchSize();
        }

        uint256[] memory leaves = _getQueuedLeaves(self);
        uint256[COMMITMENT_TREE_DEPTH] storage lastSubtrees = self
            .levelSubtrees;
        uint256 lastRoot = self.roots[self.currentRootIndex];
        uint256 nZeroLeaves = self.queueSize - insertedLeaves;

        bytes memory vParams = abi.encodePacked(
            data.proof,
            uint256(self.nextLeafIndex),
            leaves,
            lastRoot,
            lastSubtrees,
            data.newRoot,
            data.newLevelSubtrees,
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
                // COMMITMENT_MERKLE_TREE_ROOT_HISTORY_SIZE -> currentRootIndex + 1
                i = COMMITMENT_MERKLE_TREE_ROOT_HISTORY_SIZE;
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
            uint256[COMMITMENT_TREE_DEPTH] memory subtrees,
            uint256 lastRoot,
            uint8 currentRootIdx,
            uint32 nextLeafIndex
        )
    {
        // queuedLeaves is always padded to queueSize with ZERO_LEAF. Real leaves occupy the
        // front (indices 0 .. queueEndIndex-queueStartIndex-1); the remainder are ZERO_LEAF
        // sentinels. This fixed-length array matches the ZK circuit's treeUpdate input width
        // so the off-chain update service can pass it directly without reshaping.
        queuedLeaves = _getQueuedLeaves(self);
        subtrees = self.levelSubtrees;
        nextLeafIndex = self.nextLeafIndex;
        lastRoot = self.roots[self.currentRootIndex];
        currentRootIdx = self.currentRootIndex;
    }
}
