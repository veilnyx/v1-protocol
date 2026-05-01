// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IHasher} from "../interfaces/IHasher.sol";
import {FIELD_SIZE, ZERO_LEAF} from "../base/Constants.sol";

struct MerkleTree {
    uint8 depth;
    uint8 currentRootIndex;
    uint32 nextLeafIndex;
    uint40 capacity;
    address hasher;
    mapping(uint8 => uint256) roots;
    mapping(uint8 => uint256) zeroes;
    mapping(uint8 => uint256) lastSubtrees;
}

library MerkleTreeLogic {
    error MerkleTreeFull();
    error InvalidDepth(uint8 given, uint8 min, uint8 max);
    error OutOfField();

    uint8 public constant ROOT_HISTORY_SIZE = 100;

    modifier whenTreeNotFull(MerkleTree storage self) {
        if (self.nextLeafIndex >= self.capacity) {
            revert MerkleTreeFull();
        }
        _;
    }

    /// @custom:invariant MT-1: Leaves can only be appended, never modified
    /// @custom:invariant MT-2: roots[] is circular buffer of size ROOT_HISTORY_SIZE
    /// @custom:invariant MT-3: nextLeafIndex < capacity at all times
    function init(MerkleTree storage self, uint8 depth, address hasher) public {
        if(depth == 0 || depth > 31) {
            revert InvalidDepth(depth, 1, 31);
        }

        if(hasher == address(0)) {
            revert IHasher.ZeroAddress();
        }

        self.depth = depth;
        self.hasher = hasher;
        self.capacity = uint32(2 ** depth);

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

    function hashLeaves(
        MerkleTree storage self,
        uint256 leaf1,
        uint256 leaf2
    ) public view returns (uint256) {
        return IHasher(self.hasher).hash([leaf1, leaf2]);
    }

    function insert(
        MerkleTree storage self,
        uint256 leaf
    ) public whenTreeNotFull(self) returns (uint32) {
        if (leaf >= FIELD_SIZE) {
            revert OutOfField();
        }

        uint8 depth = self.depth;

        uint256 currentLevelHash = leaf;
        uint32 currentLevelIndex = self.nextLeafIndex;

        uint256 left;
        uint256 right;

        for (uint8 i = 0; i < depth; ) {
            if (currentLevelIndex % 2 == 0) {
                // Insertion on the left leaf
                left = currentLevelHash;
                right = self.zeroes[i];
                self.lastSubtrees[i] = currentLevelHash;
            } else {
                // insertion on the right leaf
                left = self.lastSubtrees[i];
                right = currentLevelHash;
            }
            // preparing for next level
            currentLevelHash = hashLeaves(self, left, right);
            currentLevelIndex /= 2;

            unchecked {
                ++i;
            }
        }

        uint8 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = currentLevelHash;
        self.nextLeafIndex = self.nextLeafIndex + 1;

        return self.nextLeafIndex;
    }

    /// @custom:invariant MT-3: Any valid root from last 100 insertions is accepted
    function isKnownRoot(
        MerkleTree storage self,
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

    function _getSubtrees(
        MerkleTree storage self
    ) internal view returns (uint256[] memory) {
        uint256[] memory subtrees = new uint256[](self.depth);

        for (uint8 i; i < uint8(self.depth); ) {
            subtrees[i] = self.lastSubtrees[i];

            unchecked {
                ++i;
            }
        }
        return subtrees;
    }

    function getState(
        MerkleTree storage self
    ) public view returns (uint256[] memory, uint256, uint8, uint32) {
        uint256[] memory lastSubtrees = _getSubtrees(self);
        uint32 nextLeafIndex = self.nextLeafIndex;
        uint256 lastRoot = self.roots[self.currentRootIndex];
        return (lastSubtrees, lastRoot, self.currentRootIndex, nextLeafIndex);
    }
}
