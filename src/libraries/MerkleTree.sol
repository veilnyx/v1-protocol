// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IHasher} from "../interfaces/IHasher.sol";
import {FIELD_SIZE, ZERO_LEAF} from "../core/Constants.sol";

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

    uint8 public constant ROOT_HISTORY_SIZE = 100;

    modifier whenTreeNotFull(MerkleTree storage self) {
        if (self.nextLeafIndex >= self.capacity) {
            revert MerkleTreeFull();
        }
        _;
    }

    function init(MerkleTree storage self, uint8 depth, address hasher) public {
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

    function insert(
        MerkleTree storage self,
        uint256[] memory leaves
    ) internal returns (uint32) {
        uint256 nLeaves = leaves.length;
        if (nLeaves == 1) {
            return insert(self, self.zeroes[0], leaves[0]);
        } else if (nLeaves == 2) {
            return insert(self, leaves[0], leaves[1]);
        } else if (nLeaves == 3) {
            return
                insert(self, self.zeroes[0], leaves[0], leaves[1], leaves[2]);
        } else if (nLeaves == 4) {
            return insert(self, leaves[0], leaves[1], leaves[2], leaves[3]);
        } else {
            revert("Unsupported number of leaves");
        }
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

    function insert(
        MerkleTree storage self,
        uint256 leaf1,
        uint256 leaf2
    ) public whenTreeNotFull(self) returns (uint32) {
        uint8 depth = self.depth;
        uint32 nextIndex = self.nextLeafIndex;

        // Index at current level
        uint256 currentLevelIndex = nextIndex / 2;

        uint256 currentLevelHash = hashLeaves(self, leaf1, leaf2);
        uint256 left;
        uint256 right;

        for (uint8 i = 1; i < depth; ) {
            if (currentLevelIndex & 1 == 0) {
                // Even/Left
                left = currentLevelHash;
                right = self.zeroes[i];
                self.lastSubtrees[i] = currentLevelHash;
            } else {
                // Odd/Right
                left = self.lastSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = hashLeaves(self, left, right);
            currentLevelIndex /= 2;

            unchecked {
                ++i;
            }
        }

        uint8 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = currentLevelHash;

        self.nextLeafIndex = nextIndex + 2;
        return self.nextLeafIndex;
    }

    function insert(
        MerkleTree storage self,
        uint256 leaf1,
        uint256 leaf2,
        uint256 leaf3,
        uint256 leaf4
    ) public whenTreeNotFull(self) returns (uint32) {
        uint8 depth = self.depth;
        uint32 nextIndex = self.nextLeafIndex;

        // Implicitely inserts 2 zero leaf nodes
        if (nextIndex % 4 != 0) {
            nextIndex += 2;
        }

        uint256 currentLevelIndex = nextIndex / 4;
        uint256 currentLevelHash = hashLeaves(
            self,
            hashLeaves(self, leaf1, leaf2),
            hashLeaves(self, leaf3, leaf4)
        );

        uint256 left;
        uint256 right;
        for (uint8 i = 2; i < depth; ) {
            if (currentLevelIndex & 1 == 0) {
                // Even/Left
                left = currentLevelHash;
                right = self.zeroes[i];
                self.lastSubtrees[i] = currentLevelHash;
            } else {
                // Odd/Right
                left = self.lastSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = hashLeaves(self, left, right);
            currentLevelIndex /= 2;

            unchecked {
                ++i;
            }
        }

        uint8 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = currentLevelHash;

        self.nextLeafIndex = nextIndex + 4;
        return self.nextLeafIndex;
    }

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

    function getRoot(
        MerkleTree storage self,
        uint8 rootIndex
    ) external view returns (uint256) {
        return self.roots[rootIndex];
    }
}
