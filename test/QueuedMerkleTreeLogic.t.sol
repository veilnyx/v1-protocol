// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BinaryIMT as BinaryIMTLogic, BinaryIMTData} from "@zk-kit/imt/BinaryIMT.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {FIELD_SIZE, ZERO_LEAF} from "src/base/Constants.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {Fixture, FixtureLib} from "./fixtures/Fixture.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";

import {console2} from "forge-std/console2.sol";

contract QueuedMerkleTreeLogicTest is BaseTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    using BinaryIMTLogic for BinaryIMTData;

    QueuedMerkleTree internal qmt;
    BinaryIMTData internal refTree;
    IHasher hasher;

    function setUp() external {
        BaseTest._setUp();
        address hasherAddr = _deployHasher();
        hasher = IHasher(hasherAddr);
        VerifierTreeUpdate treeUpdateVerifier = new VerifierTreeUpdate();

        TransactionVerifierInfo[]
            memory txvInfos = new TransactionVerifierInfo[](0);
        Verifier verifier = new Verifier(
            txvInfos,
            address(0),
            address(treeUpdateVerifier)
        );

        qmt.init(
            fixture.commitmentTreeDepth,
            fixture.commitmentTreeQueueSize,
            address(hasher),
            address(verifier)
        );

        refTree.init(fixture.commitmentTreeDepth, ZERO_LEAF);
    }

    ////////////////////////////////////////
    //// MerkleTreeInitialization Tests ////
    ////////////////////////////////////////

    // function test_qmtInitialization() public view {
    //     assertEq(qmt.depth, fixture.commitmentTreeDepth);
    //     assertEq(qmt.capacity, 2 ** fixture.commitmentTreeDepth);
    //     assertEq(qmt.queueSize, fixture.commitmentTreeQueueSize);
    //     assertEq(qmt.zeroes[0], ZERO_LEAF);
    //     assertEq(qmt.lastSubtrees[0], ZERO_LEAF);
    //     assertEq(qmt.nextLeafIndex, 0);
    //     assertEq(qmt.currentRootIndex, 0);
    // }

    // function test_zkKitTree_initialization() public view {
    //     assertEq(refTree.depth, fixture.commitmentTreeDepth);
    //     assertEq(refTree.zeroes[0], ZERO_LEAF);
    //     assertEq(refTree.numberOfLeaves, 0);
    // }

    // function test_getState() public {
    //     qmt.queueLeaves(fixture.leavesQueue1);

    //     (
    //         uint256[] memory queuedLeaves,
    //         uint256[] memory lastSubtrees,
    //         uint256 lastRoot,
    //         uint256 nextLeafIndex
    //     ) = qmt.getState();
    //     assertEq(queuedLeaves.length, fixture.leavesQueue1.length);
    // }

    function test_QCommitmentTreeLeafInsertion() public {
        qmt.queueLeaves(fixture.leavesQueue1);
        TreeUpdateData memory treeUpdateData1 = _loadTreeUpdateData(
            "tree_update_data_1"
        );
        qmt.update(treeUpdateData1);

        qmt.queueLeaves(fixture.leavesQueue2);
        TreeUpdateData memory treeUpdateData2 = _loadTreeUpdateData(
            "tree_update_data_2"
        );
        qmt.update(treeUpdateData2);
    }

    function test_QCommitmentTreeLeafInsertionWhenQueueShort() public {
        qmt.queueLeaves(fixture.leavesQueueShort);
        TreeUpdateData memory treeUpdateData1 = _loadTreeUpdateData(
            "tree_update_data_for_short_queue"
        );
        qmt.update(treeUpdateData1);

        // qmt.queueLeaves(fixture.leavesQueue2);
        // TreeUpdateData memory treeUpdateData2 = _loadTreeUpdateData(
        //     "tree_update_data_2"
        // );
        // qmt.update(treeUpdateData2);
    }
}
