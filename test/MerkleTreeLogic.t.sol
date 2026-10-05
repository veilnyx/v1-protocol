// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {BinaryIMT as BinaryIMTLogic, BinaryIMTData} from "@zk-kit/imt.sol/BinaryIMT.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTreeLogic.sol";
import {FIELD_SIZE, ZERO_LEAF, MERKLE_TREE_DEPTH} from "src/base/Constants.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";

contract MerkleTreeLogicTest is BaseTest {
    MerkleTree internal _commitmentTree;
    MerkleTree internal _addressTree;
    BinaryIMTData internal _binaryIMTToCheckCommitmentTreeRoot;
    BinaryIMTData internal _binaryIMTToCheckAddressTreeRoot;

    uint256[] public commitments;

    IHasher hasher;

    constructor() {
        hasher = _deployHasher();
    }

    function setUp() external {
        MerkleTreeLogic.init(_commitmentTree, hasher);
        BinaryIMTLogic.init(
            _binaryIMTToCheckCommitmentTreeRoot,
            MERKLE_TREE_DEPTH,
            ZERO_LEAF
        );

        MerkleTreeLogic.init(_addressTree, hasher);
        BinaryIMTLogic.init(
            _binaryIMTToCheckAddressTreeRoot,
            MERKLE_TREE_DEPTH,
            ZERO_LEAF
        );
    }

    ////////////////////////////////////////
    //// MerkleTreeInitialization Tests ////
    ////////////////////////////////////////

    function test_commitmentTree_initialization() public view {
        assertEq(_commitmentTree.levelZeros[0], ZERO_LEAF);
        assertEq(_commitmentTree.levelSubtrees[0], ZERO_LEAF);
        assertEq(_commitmentTree.nextLeafIndex, 0);
        assertEq(_commitmentTree.currentRootIndex, 0);
    }

    function test_addressTree_initialization() public view {
        assertEq(_addressTree.levelZeros[0], ZERO_LEAF);
        assertEq(_addressTree.levelSubtrees[0], ZERO_LEAF);
        assertEq(_addressTree.nextLeafIndex, 0);
        assertEq(_addressTree.currentRootIndex, 0);
    }

    function test_binaryIMT_initialization() public view {
        assertEq(_binaryIMTToCheckAddressTreeRoot.depth, MERKLE_TREE_DEPTH);
        assertEq(_binaryIMTToCheckAddressTreeRoot.zeroes[0], ZERO_LEAF);
        assertEq(_binaryIMTToCheckAddressTreeRoot.numberOfLeaves, 0);
    }

    function test_hashLeaves() public view {
        uint256 leaf1 = 1;
        uint256 leaf2 = 2;
        uint256 h = MerkleTreeLogic.hashLeaves(_commitmentTree, leaf1, leaf2);
        uint256 expected = hasher.hash([leaf1, leaf2]);
        assertEq(h, expected);
    }

    ////////////////////////////////////////
    ////// Address Merkle Tree Tests ///////
    ////////////////////////////////////////

    function test_revertWhenAddressTreeFull() external {
        _addressTree.nextLeafIndex = uint32(1 << MERKLE_TREE_DEPTH);
        uint256 commitmentLeaf = uint256(keccak256(abi.encode("commitment")));

        vm.expectRevert(MerkleTreeLogic.MerkleTreeFull.selector);
        MerkleTreeLogic.insert(_addressTree, commitmentLeaf);
    }

    function test_singleAddressInsertion() public {
        uint256 userAddress = 1;
        MerkleTreeLogic.insert(_addressTree, userAddress);
        assertEq(_addressTree.nextLeafIndex, 1);
        assertEq(_addressTree.currentRootIndex, 1);
        assertEq(_addressTree.levelSubtrees[0], userAddress);
    }

    function test_multipleAddressInsertion() public {
        uint256 userAddress1 = 1;
        uint256 userAddress2 = 2;
        MerkleTreeLogic.insert(_addressTree, userAddress1);
        MerkleTreeLogic.insert(_addressTree, userAddress2);
        assertEq(_addressTree.nextLeafIndex, 2);
        assertEq(_addressTree.currentRootIndex, 2);
        assertEq(
            _addressTree.levelSubtrees[1],
            MerkleTreeLogic.hashLeaves(_addressTree, userAddress1, userAddress2)
        );
    }

    function test_rootsOnSingleAddressInsertion() public {
        uint256 userAddress = 1;
        MerkleTreeLogic.insert(_addressTree, userAddress);
        BinaryIMTLogic.insert(_binaryIMTToCheckAddressTreeRoot, userAddress);

        uint256 binaryIMTRoot = _binaryIMTToCheckAddressTreeRoot.root;
        uint256 addressTreeRoot = _addressTree.roots[
            _addressTree.currentRootIndex
        ];

        assertEq(binaryIMTRoot, addressTreeRoot);
    }

    function test_rootsOnMultipleAddressInsertion() public {
        uint256 userAddress1 = 1;
        uint256 userAddress2 = 2;
        MerkleTreeLogic.insert(_addressTree, userAddress1);
        MerkleTreeLogic.insert(_addressTree, userAddress2);

        BinaryIMTLogic.insert(_binaryIMTToCheckAddressTreeRoot, userAddress1);
        BinaryIMTLogic.insert(_binaryIMTToCheckAddressTreeRoot, userAddress2);

        uint256 binaryIMTRoot = _binaryIMTToCheckAddressTreeRoot.root;
        uint256 addressTreeRoot = _addressTree.roots[
            _addressTree.currentRootIndex
        ];

        assertEq(binaryIMTRoot, addressTreeRoot);
    }

    ///////////////////////////////////////////
    ////// Commitment Merkle Tree Tests ///////
    ///////////////////////////////////////////

    function test_revertWhenCommitmentTreeFull() external {
        _commitmentTree.nextLeafIndex = uint32(1 << MERKLE_TREE_DEPTH);
        uint256 commitmentLeaf = uint256(keccak256(abi.encode("commitment")));

        vm.expectRevert(MerkleTreeLogic.MerkleTreeFull.selector);
        MerkleTreeLogic.insert(_commitmentTree, commitmentLeaf);
    }

    function test_isRootKnown() public {
        uint256 commitmentLeaf1 = uint256(
            keccak256(abi.encode("commitment1"))
        ) % FIELD_SIZE;

        MerkleTreeLogic.insert(_commitmentTree, commitmentLeaf1);
        uint256 commitmentTreeRoot = _commitmentTree.roots[
            _commitmentTree.currentRootIndex
        ];

        assert(
            MerkleTreeLogic.isKnownRoot(_commitmentTree, commitmentTreeRoot)
        );
    }

    /// Unwritten slots in the root-history buffer are zero, so a zero root must be
    /// rejected explicitly rather than matching one of them.
    function test_isRootKnown_rejectsZeroRoot() public {
        assertFalse(
            MerkleTreeLogic.isKnownRoot(_commitmentTree, 0),
            "zero root accepted on a fresh tree"
        );

        MerkleTreeLogic.insert(
            _commitmentTree,
            uint256(keccak256(abi.encode("commitment1"))) % FIELD_SIZE
        );

        // Still rejected once the buffer is partially written.
        assertFalse(
            MerkleTreeLogic.isKnownRoot(_commitmentTree, 0),
            "zero root accepted after insert"
        );
    }
}
