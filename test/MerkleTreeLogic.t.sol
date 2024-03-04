// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {MerkleTree, MerkleTreeLogic} from "../../src/libraries/MerkleTreeLogic.sol";
import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";

contract MerkleTreeLogicTest is Test {
    MerkleTree internal _tree;

    function test_initialization() public {
        uint256 depth = 20;
        MerkleTreeLogic.init(_tree, 20);

        assertEq(_tree.depth, depth);
        assertEq(_tree.zeroes[0], MerkleTreeLogic.ZERO_LEAF);
        assertEq(_tree.lastSubtrees[0], MerkleTreeLogic.ZERO_LEAF);
        assertEq(_tree.nextLeafIndex, 0);
        assertEq(_tree.currentRootIndex, 0);
    }

    function test_hashLeaves() public {
        uint256 leaf1 = 1;
        uint256 leaf2 = 2;
        uint256 h = MerkleTreeLogic.hashLeaves(leaf1, leaf2);
        uint256 expected = PoseidonT3.hash([leaf1, leaf2]);
        assertEq(h, expected);
    }
}
