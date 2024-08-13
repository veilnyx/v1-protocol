// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BinaryIMT as BinaryIMTLogic, BinaryIMTData} from "@zk-kit/imt/BinaryIMT.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, SubtreeUpdateData } from "src/libraries/QueuedMerkleTree.sol";
import {FIELD_SIZE, ZERO_LEAF} from "src/base/Constants.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {Fixture, FixtureLib} from "./fixtures/Fixture.sol";
import {VerifierSubtreeUpdate} from "src/verifiers/VerifierSubtreeUpdate.sol";

contract QueuedMerkleTreeLogicTest is BaseTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    using BinaryIMTLogic for BinaryIMTData;

    QueuedMerkleTree internal _queuedCommitmentTree;
    BinaryIMTData internal _zkKitTree;
    uint8 public commitmentTreeDepth;
    uint256[] public leavesQueue;
    IHasher hasher;

    function setUp() external {
        BaseTest._setUp();
        commitmentTreeDepth = fixture.commitmentTreeDepth;
        leavesQueue = fixture.leavesQueue;
        address hasherAddr = _deployHasher();
        hasher = IHasher(hasherAddr);
        VerifierSubtreeUpdate subtreeUpdateDataVerifier = new VerifierSubtreeUpdate();

        _queuedCommitmentTree.init(
            commitmentTreeDepth,
            address(hasher),
            address(subtreeUpdateDataVerifier)
        );

        _zkKitTree.init(
            commitmentTreeDepth,
            ZERO_LEAF
        );
    }

    ////////////////////////////////////////
    //// MerkleTreeInitialization Tests ////
    ////////////////////////////////////////

    function test_commitmentTree_initialization() public view {
        assertEq(_queuedCommitmentTree.depth, commitmentTreeDepth);
        assertEq(_queuedCommitmentTree.zeroes[0], ZERO_LEAF);
        assertEq(_queuedCommitmentTree.lastSubtrees[0], ZERO_LEAF);
        assertEq(_queuedCommitmentTree.nextLeafIndex, 0);
        assertEq(_queuedCommitmentTree.currentRootIndex, 0);
    }

    function test_zkKitTree_initialization() public view {
        assertEq(_zkKitTree.depth, commitmentTreeDepth);
        assertEq(_zkKitTree.zeroes[0], ZERO_LEAF);
        assertEq(_zkKitTree.numberOfLeaves, 0);
    }

    ///////////////////////////////////////////
    ////// Commitment Merkle Tree Tests ///////
    ///////////////////////////////////////////

    function test_rootsOnCommitmentTreeQuadLeafInsertion() public {
        _queuedCommitmentTree.queueLeaves(leavesQueue);
        for (uint i = 0; i < 10; i++) {
            _zkKitTree.insert(
                leavesQueue[i]
            );
        }
        
        uint256 zkKitTreeRoot = _zkKitTree.root;
        uint256[] memory zkKitTreeLastSubtrees = new uint256[](commitmentTreeDepth);
        for(uint i; i < commitmentTreeDepth; ) {
            zkKitTreeLastSubtrees[i] = _zkKitTree.lastSubtrees[i][0]; // @todo reconfirm if this is right
            unchecked{
                ++i;
            }
        }
        bytes memory subtreeUpdateProof = _loadData("subtreeUpdateData");

        SubtreeUpdateData memory subtreeUpdateData = SubtreeUpdateData({
            newRoot: zkKitTreeRoot,
            newSubtrees: zkKitTreeLastSubtrees,
            proof: subtreeUpdateProof
        });

        uint256 leafIndexBeforeQueueInsertion = _queuedCommitmentTree.nextLeafIndex;
        uint256 leafIndexAfterQueueInsertion = _queuedCommitmentTree.update(subtreeUpdateData);
        assert(leafIndexAfterQueueInsertion > leafIndexBeforeQueueInsertion);
    }
}
