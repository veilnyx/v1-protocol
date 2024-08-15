// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BinaryIMT as BinaryIMTLogic, BinaryIMTData} from "@zk-kit/imt/BinaryIMT.sol";
import {MerkleTree, MerkleTreeLogic} from "../src/libraries/MerkleTree.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {FIELD_SIZE, ZERO_LEAF} from "src/base/Constants.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {Fixture, FixtureLib} from "./fixtures/Fixture.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";

import {console2} from "forge-std/console2.sol";

contract QueuedMerkleTreeLogicTest is PoolTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    using BinaryIMTLogic for BinaryIMTData;
    using MerkleTreeLogic for MerkleTree;

    QueuedMerkleTree internal qmt;
    ZTransaction internal depositTx;
    // BinaryIMTData internal refTree;
    MerkleTree internal refTree;
    IHasher hasher;

    function setUp() external {
        PoolTest._setUp();
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

        refTree.init(fixture.commitmentTreeDepth, address(hasher));
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
        TreeUpdateData memory treeUpdateData1 = _loadTreeUpdateData(
            "tree_update_data_partial_queue"
        );
        qmt.update(treeUpdateData1);
    }

    function test_CommitmentEventEmitsOnlyForNonZeroLeaves() public {
        qmt.queueLeaves(fixture.leavesQueuePartial);
        TreeUpdateData memory treeUpdateData1 = _loadTreeUpdateData(
            "tree_update_data_partial_queue"
        );

        // Expected emits only for non zero leaves
        for (uint8 i; i < fixture.leavesQueuePartial.length; ) {
            vm.expectEmit(true, true, true, true);
            emit IPool.Commitment(i, fixture.leavesQueuePartial[i]);
            unchecked {
                ++i;
            }
        }
        qmt.update(treeUpdateData1); // this will pad ZERO_LEAF but will not emit them
    }

    function test_CommitmentEventEmitsAllLeaves() public {
        qmt.queueLeaves(fixture.leavesQueue1);
        TreeUpdateData memory treeUpdateData1 = _loadTreeUpdateData(
            "tree_update_data_1"
        );

        // Expected emits only for non zero leaves
        for (uint8 i; i < fixture.leavesQueue1.length; ) {
            vm.expectEmit(true, true, true, true);
            emit IPool.Commitment(i, fixture.leavesQueue1[i]);
            unchecked {
                ++i;
            }
        }
        qmt.update(treeUpdateData1); // this will pad ZERO_LEAF but will not emit them
    }

    function test_txTest() public {
        _mintAsset(asset1, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);

        ZTransaction memory depositTx = _loadShieldedTransaction(
            "deposit_1000_weth_without_fee"
        );
        pool.transact(depositTx); // will add commitments to the queue
        uint256 poolBalAfterDeposit = IERC20(address(token1)).balanceOf(
            address(pool)
        );

        // UPDATE QUEUE MT SERVICE 
        // service reading the queue and generating new merkle tree state on-chain
        (uint256[] memory leaves, , , ) = pool.getCommitmentTreeState();
        for (uint8 i; i < leaves.length; ) {
            console2.log('leaf inserted onchain:', leaves[i]);
            refTree.insert(leaves[i]);
            unchecked {
                ++i;
            }
        }

        TreeUpdateData memory treeUpdateData = TreeUpdateData({
            newRoot: refTree.getLatestRoot(),
            newSubtrees: refTree.getLastSubtrees(),
            proof: bytes("")
        });

        pool.updateCommitmentTree(treeUpdateData); // inserting deposit tx commitments into the qmt

        ( , , , uint32 latestRoot ) = pool.getCommitmentTreeState();
        console2.log('onchain root after deposit:', latestRoot);

        // executing withdraw tx now
        ZTransaction memory withdrawTx = _loadShieldedTransaction(
            "withdraw_500_weth_without_fee"
        );
        pool.transact(withdrawTx);
        uint256 poolBalAfterWithdraw = IERC20(address(token1)).balanceOf(
            address(pool)
        );

        console2.log('poolBalAfterDeposit:', poolBalAfterDeposit);
        console2.log('poolBalAfterWithdraw:', poolBalAfterWithdraw);

        // assert(poolBalAfterDeposit == 1000 ether);
        // assert(poolBalAfterWithdraw == 500 ether);
        // assert(poolBalAfterDeposit > poolBalAfterWithdraw);
    }
}
