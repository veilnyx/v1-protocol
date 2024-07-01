// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BinaryIMT as BinaryIMTLogic, BinaryIMTData} from "@zk-kit/imt/BinaryIMT.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTree.sol";
import {FIELD_SIZE, ZERO_LEAF} from "src/base/Constants.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";

contract MerkleTreeLogicTest is BaseTest {
    MerkleTree internal _commitmentTree;
    MerkleTree internal _addressTree;
    BinaryIMTData internal _binaryIMTToCheckCommitmentTreeRoot;
    BinaryIMTData internal _binaryIMTToCheckAddressTreeRoot;

    uint8 public constant commitmentTreeDepth = 20;
    uint8 public constant addressTreeDepth = 10;

    uint256[] public commitments;

    IHasher hasher;

    constructor() {
        address hasherAddr = _deployHasher();
        hasher = IHasher(hasherAddr);
    }

    function setUp() external {
        MerkleTreeLogic.init(
            _commitmentTree,
            commitmentTreeDepth,
            address(hasher)
        );
        BinaryIMTLogic.init(
            _binaryIMTToCheckCommitmentTreeRoot,
            commitmentTreeDepth,
            ZERO_LEAF
        );

        MerkleTreeLogic.init(_addressTree, addressTreeDepth, address(hasher));
        BinaryIMTLogic.init(
            _binaryIMTToCheckAddressTreeRoot,
            addressTreeDepth,
            ZERO_LEAF
        );
    }

    ////////////////////////////////////////
    //// MerkleTreeInitialization Tests ////
    ////////////////////////////////////////

    function test_commitmentTree_initialization() public view {
        assertEq(_commitmentTree.depth, commitmentTreeDepth);
        assertEq(_commitmentTree.zeroes[0], ZERO_LEAF);
        assertEq(_commitmentTree.lastSubtrees[0], ZERO_LEAF);
        assertEq(_commitmentTree.nextLeafIndex, 0);
        assertEq(_commitmentTree.currentRootIndex, 0);
    }

    function test_addressTree_initialization() public view {
        assertEq(_addressTree.depth, addressTreeDepth);
        assertEq(_addressTree.zeroes[0], ZERO_LEAF);
        assertEq(_addressTree.lastSubtrees[0], ZERO_LEAF);
        assertEq(_addressTree.nextLeafIndex, 0);
        assertEq(_addressTree.currentRootIndex, 0);
    }

    function test_binaryIMT_initialization() public view {
        assertEq(_binaryIMTToCheckAddressTreeRoot.depth, addressTreeDepth);
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
        _addressTree.nextLeafIndex = uint32(2 ** addressTreeDepth);
        uint256 commitmentLeaf = uint256(keccak256(abi.encode("commitment")));

        vm.expectRevert(
            abi.encodeWithSelector(MerkleTreeLogic.MerkleTreeFull.selector)
        );
        MerkleTreeLogic.insert(_addressTree, commitmentLeaf);
    }

    function test_singleAddressInsertion() public {
        uint256 userAddress = 1;
        MerkleTreeLogic.insert(_addressTree, userAddress);
        assertEq(_addressTree.nextLeafIndex, 1);
        assertEq(_addressTree.currentRootIndex, 1);
        assertEq(_addressTree.lastSubtrees[0], userAddress);
    }

    function test_multipleAddressInsertion() public {
        uint256 userAddress1 = 1;
        uint256 userAddress2 = 2;
        MerkleTreeLogic.insert(_addressTree, userAddress1);
        MerkleTreeLogic.insert(_addressTree, userAddress2);
        assertEq(_addressTree.nextLeafIndex, 2);
        assertEq(_addressTree.currentRootIndex, 2);
        assertEq(
            _addressTree.lastSubtrees[1],
            MerkleTreeLogic.hashLeaves(_addressTree, userAddress1, userAddress2)
        );
    }

    function test_rootsOnSingleAddressInsertion() public {
        uint256 userAddress = 1;
        MerkleTreeLogic.insert(_addressTree, userAddress);
        BinaryIMTLogic.insert(_binaryIMTToCheckAddressTreeRoot, userAddress); // BinaryIMT::insert() expects the leaf to be already hashed

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

        BinaryIMTLogic.insert(_binaryIMTToCheckAddressTreeRoot, userAddress1); // BinaryIMT::insert() expects the leaf to be already hashed
        BinaryIMTLogic.insert(_binaryIMTToCheckAddressTreeRoot, userAddress2); // BinaryIMT::insert() expects the leaf to be already hashed

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
        _commitmentTree.nextLeafIndex = uint32(2 ** commitmentTreeDepth);
        uint256 commitmentLeaf = uint256(keccak256(abi.encode("commitment")));
        commitments.push(commitmentLeaf);

        vm.expectRevert(
            abi.encodeWithSelector(MerkleTreeLogic.MerkleTreeFull.selector)
        );
        MerkleTreeLogic.insert(_commitmentTree, commitments);
    }

    function test_commitmentTreeDuoLeafInsertion() public {
        uint256 commitmentLeaf1 = uint256(keccak256(abi.encode("commitment1")));
        uint256 commitmentLeaf2 = uint256(keccak256(abi.encode("commitment2")));
        uint256 commitmentsHashed = MerkleTreeLogic.hashLeaves(
            _commitmentTree,
            commitmentLeaf1,
            commitmentLeaf2
        );

        commitments.push(commitmentLeaf1);
        commitments.push(commitmentLeaf2);
        MerkleTreeLogic.insert(_commitmentTree, commitments);

        assertEq(_commitmentTree.nextLeafIndex, 2);
        assertEq(_commitmentTree.currentRootIndex, 1);
        assertEq(_commitmentTree.lastSubtrees[1], commitmentsHashed);
    }

    function test_rootsOnCommitmentTreeDuoLeafInsertion() public {
        uint256 commitmentLeaf1 = uint256(
            keccak256(abi.encode("commitment1"))
        ) % FIELD_SIZE;
        uint256 commitmentLeaf2 = uint256(
            keccak256(abi.encode("commitment2"))
        ) % FIELD_SIZE;

        // inserting both leaves together in the commitment tree
        commitments.push(commitmentLeaf1);
        commitments.push(commitmentLeaf2);
        MerkleTreeLogic.insert(_commitmentTree, commitments);
        uint256 commitmentTreeRoot = _commitmentTree.roots[
            _commitmentTree.currentRootIndex
        ];

        BinaryIMTLogic.insert(
            _binaryIMTToCheckCommitmentTreeRoot,
            commitmentLeaf1
        );
        BinaryIMTLogic.insert(
            _binaryIMTToCheckCommitmentTreeRoot,
            commitmentLeaf2
        );
        uint256 binaryIMTRoot = _binaryIMTToCheckCommitmentTreeRoot.root;

        uint256 commitmentTreeLastSubTree1 = _commitmentTree.lastSubtrees[1];
        uint256 binaryIMTLastSubTree1 = _binaryIMTToCheckCommitmentTreeRoot
            .lastSubtrees[1][0];

        assertEq(binaryIMTRoot, commitmentTreeRoot);
        assertEq(commitmentTreeLastSubTree1, binaryIMTLastSubTree1);
    }

    function test_isRootKnown() public {
        uint256 commitmentLeaf1 = uint256(
            keccak256(abi.encode("commitment1"))
        ) % FIELD_SIZE;
        uint256 commitmentLeaf2 = uint256(
            keccak256(abi.encode("commitment2"))
        ) % FIELD_SIZE;

        // inserting both leaves together in the commitment tree
        commitments.push(commitmentLeaf1);
        commitments.push(commitmentLeaf2);
        MerkleTreeLogic.insert(_commitmentTree, commitments);
        uint256 commitmentTreeRoot = _commitmentTree.roots[
            _commitmentTree.currentRootIndex
        ];

        assert(
            MerkleTreeLogic.isKnownRoot(_commitmentTree, commitmentTreeRoot)
        );
    }

    function test_commitmentTreeQuadLeafInsertion() public {
        uint256[] memory leafDuoHashes = new uint256[](2);
        uint8 leafDuoIndex = 0;

        for (uint i = 1; i <= 4; i++) {
            commitments.push(uint256(keccak256(abi.encode("commitment", i))));

            if (i % 2 == 0) {
                leafDuoHashes[leafDuoIndex] = MerkleTreeLogic.hashLeaves(
                    _commitmentTree,
                    commitments[i - 2],
                    commitments[i - 1]
                );
                leafDuoIndex++;
            }
        }
        uint256 commitmentsHashed = MerkleTreeLogic.hashLeaves(
            _commitmentTree,
            leafDuoHashes[0],
            leafDuoHashes[1]
        );

        MerkleTreeLogic.insert(_commitmentTree, commitments);

        assertEq(_commitmentTree.nextLeafIndex, 4);
        assertEq(_commitmentTree.currentRootIndex, 1);
        assertEq(_commitmentTree.lastSubtrees[2], commitmentsHashed);
    }

    function test_rootsOnCommitmentTreeQuadLeafInsertion() public {
        for (uint i = 0; i < 4; i++) {
            commitments.push(
                uint256(keccak256(abi.encode("commitment", i + 1))) % FIELD_SIZE
            );
        }

        // inserting both leaves together in the commitment tree
        MerkleTreeLogic.insert(_commitmentTree, commitments);
        uint256 commitmentTreeRoot = _commitmentTree.roots[
            _commitmentTree.currentRootIndex
        ];

        for (uint i = 0; i < 4; i++) {
            BinaryIMTLogic.insert(
                _binaryIMTToCheckCommitmentTreeRoot,
                commitments[i]
            );
        }
        uint256 binaryIMTRoot = _binaryIMTToCheckCommitmentTreeRoot.root;

        uint256 commitmentTreeLastSubTree2 = _commitmentTree.lastSubtrees[2];
        uint256 binaryIMTLastSubTree2 = _binaryIMTToCheckCommitmentTreeRoot
            .lastSubtrees[2][0];

        assertEq(binaryIMTRoot, commitmentTreeRoot);
        assertEq(commitmentTreeLastSubTree2, binaryIMTLastSubTree2);
    }
}
