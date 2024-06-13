// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTree.sol";
import {BinaryIMT as BinaryIMTLogic, BinaryIMTData} from "@zk-kit/imt/contracts/BinaryIMT.sol";
import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";
import {PoseidonT2} from "poseidon-solidity/PoseidonT2.sol";

contract MerkleTreeLogicTest is Test {
    MerkleTree internal _commitmentTree;
    MerkleTree internal _addressTree;
    BinaryIMTData internal _binaryIMT;

    uint256 public constant commitmentTreeDepth = 20;
    uint256 public constant addressTreeDepth = 10;

    function setUp() external {
        MerkleTreeLogic.init(_commitmentTree, commitmentTreeDepth);
        MerkleTreeLogic.init(_addressTree, addressTreeDepth);
        BinaryIMTLogic.init(
            _binaryIMT,
            addressTreeDepth,
            MerkleTreeLogic.ZERO_LEAF
        );
    }

    function test_commitmentTree_initialization() public view {
        assertEq(_commitmentTree.depth, commitmentTreeDepth);
        assertEq(_commitmentTree.zeroes[0], MerkleTreeLogic.ZERO_LEAF);
        assertEq(_commitmentTree.lastSubtrees[0], MerkleTreeLogic.ZERO_LEAF);
        assertEq(_commitmentTree.nextLeafIndex, 0);
        assertEq(_commitmentTree.currentRootIndex, 0);
    }

    function test_addressTree_initialization() public view {
        assertEq(_addressTree.depth, addressTreeDepth);
        assertEq(_addressTree.zeroes[0], MerkleTreeLogic.ZERO_LEAF);
        assertEq(_addressTree.lastSubtrees[0], MerkleTreeLogic.ZERO_LEAF);
        assertEq(_addressTree.nextLeafIndex, 0);
        assertEq(_addressTree.currentRootIndex, 0);
    }

    function test_binaryIMT_initialization() public view {
        assertEq(_binaryIMT.depth, addressTreeDepth);
        assertEq(_binaryIMT.zeroes[0], MerkleTreeLogic.ZERO_LEAF);
        assertEq(_binaryIMT.numberOfLeaves, 0);
    }

    function test_hashLeaves() public pure {
        uint256 leaf1 = 1;
        uint256 leaf2 = 2;
        uint256 h = MerkleTreeLogic.hashLeaves(leaf1, leaf2);
        uint256 expected = PoseidonT3.hash([leaf1, leaf2]);
        assertEq(h, expected);
    }

    function test_singleAddressInsertion() public {
        uint256 userAddress = 1;
        uint256 userAddressHashed = PoseidonT2.hash([userAddress]);
        MerkleTreeLogic.insert(_addressTree, userAddress);
        assertEq(_addressTree.nextLeafIndex, 1);
        assertEq(_addressTree.currentRootIndex, 1);
        assertEq(_addressTree.lastSubtrees[0], userAddressHashed);
    }

    function test_multipleAddressInsertion() public {
        uint256 userAddress1 = 1;
        uint256 userAddress2 = 2;
        uint256 userAddress1Hashed = PoseidonT2.hash([userAddress1]);
        uint256 userAddress2Hashed = PoseidonT2.hash([userAddress2]);
        MerkleTreeLogic.insert(_addressTree, userAddress1);
        MerkleTreeLogic.insert(_addressTree, userAddress2);
        assertEq(_addressTree.nextLeafIndex, 2);
        assertEq(_addressTree.currentRootIndex, 2);
        assertEq(_addressTree.lastSubtrees[1], MerkleTreeLogic.hashLeaves(userAddress1Hashed, userAddress2Hashed));
    }

    function test_rootsOnSingleAddressInsertion() public {
        uint256 userAddress = 1;
        MerkleTreeLogic.insert(_addressTree, userAddress);
        BinaryIMTLogic.insert(_binaryIMT, PoseidonT2.hash([userAddress])); // BinaryIMT::insert() expects the leaf to be already hashed

        uint256 binaryIMTRoot = _binaryIMT.root;
        uint256 addressTreeRoot = _addressTree.roots[_addressTree.currentRootIndex];

        assertEq(binaryIMTRoot, addressTreeRoot);
    }

     function test_rootsOnMultipleAddressInsertion() public {
        uint256 userAddress1 = 1;
        uint256 userAddress2 = 2;
        MerkleTreeLogic.insert(_addressTree, userAddress1);
        MerkleTreeLogic.insert(_addressTree, userAddress2);

        BinaryIMTLogic.insert(_binaryIMT, PoseidonT2.hash([userAddress1])); // BinaryIMT::insert() expects the leaf to be already hashed
        BinaryIMTLogic.insert(_binaryIMT, PoseidonT2.hash([userAddress2])); // BinaryIMT::insert() expects the leaf to be already hashed

        uint256 binaryIMTRoot = _binaryIMT.root;
        uint256 addressTreeRoot = _addressTree.roots[_addressTree.currentRootIndex];

        assertEq(binaryIMTRoot, addressTreeRoot);
    }
}
