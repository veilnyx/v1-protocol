// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";
import {PoseidonT2} from "poseidon-solidity/PoseidonT2.sol";

struct MerkleTree {
    uint256 depth;
    uint256 nextLeafIndex;
    uint256 currentRootIndex;
    mapping(uint256 => uint256) roots;
    mapping(uint256 => uint256) zeroes;
    mapping(uint256 => uint256) lastSubtrees;
}

library MerkleTreeLogic {
    error MerkleTreeFull();
    
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant ZERO_LEAF = uint256(keccak256("zkFi")) % FIELD_SIZE;
    uint8 public constant ROOT_HISTORY_SIZE = 101;

    modifier whenTreeNotFull(MerkleTree storage self) {
        if(self.nextLeafIndex >= (2 ** self.depth)) {
            revert MerkleTreeFull();
        }
        _;
    }

    function init(MerkleTree storage self, uint256 depth) public {
        self.depth = depth;

        uint256 zero = ZERO_LEAF;
        for (uint8 i = 0; i < depth; ) {
            self.zeroes[i] = zero;
            self.lastSubtrees[i] = zero;
            zero = hashLeaves(zero, zero);

            unchecked {
                ++i;
            }
        }

        self.roots[0] = zero;
    }

    function insert(
        MerkleTree storage self,
        uint256[] memory leaves
    ) internal returns (uint256) {
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
        uint256 leaf1,
        uint256 leaf2
    ) public pure returns (uint256) {
        return PoseidonT3.hash([leaf1, leaf2]);
    }

    function insert(
        MerkleTree storage self,
        uint256 userAddress
    ) public whenTreeNotFull(self) returns (uint256) {
        uint256 depth = self.depth;

        uint256 currentLevelHash = PoseidonT2.hash([userAddress]);
        uint256 currentLevelIndex = self.nextLeafIndex;

        uint256 left;
        uint256 right;

        for (uint256 l = 0; l < depth; l++) {
            if (currentLevelIndex % 2 == 0) {
                // Insertion on the left leaf
                left = currentLevelHash;
                right = self.zeroes[l];
                self.lastSubtrees[l] = currentLevelHash;
            } else {
                // insertion on the right leaf
                left = self.lastSubtrees[l];
                right = currentLevelHash;
            }
            // preparing for next level
            currentLevelHash = hashLeaves(left, right);
            currentLevelIndex /= 2;
        }

        self.nextLeafIndex++;
        uint256 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = currentLevelHash;

        return self.nextLeafIndex;
    }

    function insert(
        MerkleTree storage self,
        uint256 leaf1,
        uint256 leaf2
    ) public whenTreeNotFull(self) returns (uint256) {
        uint256 depth = self.depth;
        uint256 nextIndex = self.nextLeafIndex;

        // Index at current level
        uint256 currentLevelIndex = nextIndex / 2;

        uint256 currentLevelHash = hashLeaves(leaf1, leaf2);
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
            currentLevelHash = hashLeaves(left, right);
            currentLevelIndex /= 2;

            unchecked {
                ++i;
            }
        }

        uint256 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
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
    ) public whenTreeNotFull(self) returns (uint256) {
        uint256 depth = self.depth;
        uint256 nextIndex = self.nextLeafIndex;

        // Implicitely inserts 2 zero leaf nodes
        if (nextIndex % 4 != 0) {
            nextIndex += 2;
        }

        uint256 currentLevelIndex = nextIndex / 4;
        uint256 currentLevelHash = hashLeaves(
            hashLeaves(leaf1, leaf2),
            hashLeaves(leaf3, leaf4)
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
            currentLevelHash = hashLeaves(left, right);
            currentLevelIndex /= 2;

            unchecked {
                ++i;
            }
        }

        uint256 newRootIndex = (self.currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        self.currentRootIndex = newRootIndex;
        self.roots[newRootIndex] = currentLevelHash;

        self.nextLeafIndex = nextIndex + 4;
        return self.nextLeafIndex;
    }

    function isKnownRoot(
        MerkleTree storage self,
        uint256 root
    ) public view returns (bool) {
        uint256 from = self.currentRootIndex > ROOT_HISTORY_SIZE - 1
            ? self.currentRootIndex - ROOT_HISTORY_SIZE - 1
            : 0;

        uint8 i = 0;
        while (i <= self.currentRootIndex) {
            if (self.roots[i + from] == root) {
                return true;
            }

            unchecked {
                ++i;
            }
        }

        return false;
    }

    function getMerkleRoot(MerkleTree storage self, uint8 rootIndex) external view returns(uint256) {
        return self.roots[rootIndex];
    }
}
