// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IHasher} from "../interfaces/IHasher.sol";
import {FIELD_SIZE, ZERO_LEAF, USER_REGISTER_MERKLE_TREE_ROOT_HISTORY_SIZE, MERKLE_TREE_DEPTH} from "../base/Constants.sol";

struct MerkleTree {
    uint8 currentRootIndex;
    uint32 nextLeafIndex;
    uint32 capacity;
    IHasher hasher;
    mapping(uint8 => uint256) roots;
    uint256[MERKLE_TREE_DEPTH] levelZeros;
    uint256[MERKLE_TREE_DEPTH] levelSubtrees;
}

library MerkleTreeLogic {
    error MerkleTreeFull();
    error OutOfField();
    error ZeroAddress();

    modifier whenTreeNotFull(MerkleTree storage self) {
        if (self.nextLeafIndex >= self.capacity) {
            revert MerkleTreeFull();
        }
        _;
    }

    /// @custom:invariant MT-1: Leaves can only be appended, never modified
    /// @custom:invariant MT-2: roots[] is circular buffer of size USER_REGISTER_MERKLE_TREE_ROOT_HISTORY_SIZE
    /// @custom:invariant MT-3: nextLeafIndex < capacity at all times
    function init(MerkleTree storage self, IHasher hasher) public {
        if (address(hasher) == address(0)) {
            revert ZeroAddress();
        }

        self.hasher = hasher;
        self.capacity = uint32(1 << MERKLE_TREE_DEPTH);

        uint256 zero = ZERO_LEAF;
        for (uint8 i = 0; i < MERKLE_TREE_DEPTH; ) {
            self.levelZeros[i] = zero;
            self.levelSubtrees[i] = zero;
            zero = hasher.hash([zero, zero]);

            unchecked {
                ++i;
            }
        }

        self.roots[0] = zero;
    }

    function hashLeaves(
        MerkleTree storage self,
        uint256 leaf1,
        uint256 leaf2
    ) public view returns (uint256) {
        return self.hasher.hash([leaf1, leaf2]);
    }

    function insert(
        MerkleTree storage self,
        uint256 leaf
    ) public whenTreeNotFull(self) returns (uint32) {
        if (leaf >= FIELD_SIZE) {
            revert OutOfField();
        }

        uint32 leafInsertIndex = self.nextLeafIndex;

        uint256 currentLevelHash = leaf;
        uint32 currentLevelIndex = leafInsertIndex;

        uint256 left;
        uint256 right;

        for (uint8 i = 0; i < MERKLE_TREE_DEPTH; ) {
            if (currentLevelIndex % 2 == 0) {
                // Insertion on the left leaf
                left = currentLevelHash;
                right = self.levelZeros[i];
                self.levelSubtrees[i] = currentLevelHash;
            } else {
                // insertion on the right leaf
                left = self.levelSubtrees[i];
                right = currentLevelHash;
            }
            // preparing for next level
            currentLevelHash = hashLeaves(self, left, right);
            currentLevelIndex /= 2;

            unchecked {
                ++i;
            }
        }

        uint8 newRootIndex = (self.currentRootIndex + 1) %
            USER_REGISTER_MERKLE_TREE_ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = currentLevelHash;
        self.nextLeafIndex = leafInsertIndex + 1;

        return leafInsertIndex + 1;
    }

    /// @custom:invariant MT-3: Any valid root from last 100 insertions is accepted
    function isKnownRoot(
        MerkleTree storage self,
        uint256 _root
    ) public view returns (bool) {
        uint8 _currentRootIndex = self.currentRootIndex;
        uint8 i = _currentRootIndex; // currentRootIndex -> 0
        do {
            if (_root == self.roots[i]) {
                return true;
            }
            if (i == 0) {
                // USER_REGISTER_MERKLE_TREE_ROOT_HISTORY_SIZE -> currentRootIndex + 1
                i = USER_REGISTER_MERKLE_TREE_ROOT_HISTORY_SIZE;
            }
            i--;
        } while (i != _currentRootIndex);
        return false;
    }

    function getState(
        MerkleTree storage self
    )
        public
        view
        returns (
            uint256[MERKLE_TREE_DEPTH] memory subtrees,
            uint256 lastRoot,
            uint8 currentRootIdx,
            uint32 nextLeafIndex
        )
    {
        subtrees = self.levelSubtrees;
        nextLeafIndex = self.nextLeafIndex;
        lastRoot = self.roots[self.currentRootIndex];
        currentRootIdx = self.currentRootIndex;
    }
}
