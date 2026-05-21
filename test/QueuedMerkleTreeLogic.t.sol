// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BinaryIMT as BinaryIMTLogic, BinaryIMTData} from "@zk-kit/imt.sol/BinaryIMT.sol";
import {MerkleTree, MerkleTreeLogic} from "../src/libraries/MerkleTree.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {FIELD_SIZE, ZERO_LEAF} from "src/base/Constants.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {Fixture, FixtureLib} from "./fixtures/Fixture.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";

import {console2} from "forge-std/console2.sol";

contract QueuedMerkleTreeLogicTest is BaseTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    using BinaryIMTLogic for BinaryIMTData;
    using MerkleTreeLogic for MerkleTree;

    QueuedMerkleTree internal qmt;
    MerkleTree internal refTree;
    IHasher internal hasher;

    function setUp() external {
        _setUp();
        hasher = _deployHasher();
        VerifierTreeUpdate treeUpdateVerifier = new VerifierTreeUpdate();

        TransactionVerifierInfo[]
            memory txvInfos = new TransactionVerifierInfo[](0);
        VerifierRegister addressVerifier_ = new VerifierRegister();
        Verifier verifier_ = new Verifier(
            txvInfos,
            address(addressVerifier_),
            address(treeUpdateVerifier),
            address(this)
        );

        qmt.init(
            fixture.commitmentTreeDepth,
            fixture.commitmentTreeQueueSize,
            hasher,
            verifier_
        );

        refTree.init(fixture.commitmentTreeDepth, hasher);
    }

    ////////////////////////////////////////
    //// MerkleTreeInitialization Tests ////
    ////////////////////////////////////////

    function test_qmtInitialization() public view {
        assertEq(qmt.depth, fixture.commitmentTreeDepth);
        assertEq(qmt.capacity, 2 ** fixture.commitmentTreeDepth);
        assertEq(qmt.queueSize, fixture.commitmentTreeQueueSize);
        assertEq(qmt.levels[0].zero, ZERO_LEAF);
        assertEq(qmt.levels[0].lastSubtree, ZERO_LEAF);
        assertEq(qmt.nextLeafIndex, 0);
        assertEq(qmt.currentRootIndex, 0);
    }

    function test_updateTree() public {
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

    function test_updateTreeWithPartialQueue() public {
        qmt.queueLeaves(fixture.leavesQueuePartial);
        TreeUpdateData memory partialTreeUpdateData1 = _loadTreeUpdateData(
            "tree_update_data_partial_queue"
        );
        qmt.update(partialTreeUpdateData1);

        qmt.queueLeaves(fixture.leavesQueue2);
        TreeUpdateData memory treeUpdateData2 = _loadTreeUpdateData(
            "tree_update_data_post_partial_update"
        );
        qmt.update(treeUpdateData2);
    }
}
