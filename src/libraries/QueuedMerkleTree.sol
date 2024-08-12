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
    mapping(uint256 => uint256) queuedLeaves;
    mapping(uint8 => uint256) roots;
    mapping(uint8 => uint256) zeroes;
    mapping(uint8 => uint256) lastSubtrees;
}

struct SubtreeUpdateInputs {
    uint32 leafIndex;
    uint256[10] leaves;
    uint256 lastRoot;
    uint256[25] lastSubtrees;
    uint256 newRoot;
    uint256[25] newSubtrees;
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
            self.queuedLeaves[self.nextLeafIndex + i] = leaves[i];
            unchecked {
                ++i;
            }
        }

        self.nextLeafIndex += uint32(leaves.length);
    }

    function updateSubtree(
        SubtreeUpdateInputs memory subtreeUpdateInputs,
        address subtreeVerifier,
        QueuedMerkleTree storage self
    ) internal returns (uint256) {
        bool subtreeUpdateProofVerification = _verifySubtreeUpdateProof(
            subtreeUpdateInputs,
            subtreeVerifier
        );

        if (subtreeUpdateProofVerification) {
            uint8 newRootIndex = (self.currentRootIndex + 1) %
                ROOT_HISTORY_SIZE;
            self.roots[newRootIndex] = subtreeUpdateInputs.newRoot;

            for (uint8 i = 0; i < self.depth; ) {
                self.lastSubtrees[i] = subtreeUpdateInputs.newSubtrees[i];
                unchecked {
                    ++i;
                }
            }

            self.nextLeafIndex += self.queueSize;
        } else {
            revert IPool.InvalidSubtreeUpdateProof();
        }

        return self.nextLeafIndex;
    }

    function _verifySubtreeUpdateProof(
        SubtreeUpdateInputs memory subtreeUpdateInputs,
        address subtreeVerifier
    ) internal view returns (bool) {
        
        bytes memory vInp = abi.encodePacked(
            subtreeUpdateInputs.subtreeUpdateProof,
            subtreeUpdateInputs.leafIndex,
            subtreeUpdateInputs.leaves,
            subtreeUpdateInputs.lastRoot,
            subtreeUpdateInputs.lastSubtrees,
            subtreeUpdateInputs.newRoot,
            subtreeUpdateInputs.newSubtrees
        );
        bool subtreeVerificationResult = IVerifier(subtreeVerifier)
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
