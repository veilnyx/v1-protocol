// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHasher} from "src/interfaces/IHasher.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {ZERO_LEAF} from "src/base/Constants.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";

/// A tree-update proof must stay valid when more leaves are queued after it was generated.
///
/// The treeUpdate circuit takes all `queueSize` leaves as public inputs and requires every leaf
/// after the batch to be a zero leaf. The proof therefore depends on the batch's own leaves and
/// `batchSize`, and must not depend on what is queued behind them. If the contract fills the
/// padding slots from queue state, any later `transact` changes a public input and invalidates an
/// in-flight proof. Anyone can do that, so the tree can be kept from advancing.
///
/// These tests use a REAL Groth16 proof and the production tree-update verifier (`src/verifiers`).
/// `AuditQueueAccounting` covers the same property with a verifier that always accepts, so it
/// checks the accounting only and cannot catch this.
///
/// Fixture: `poc_tree_update_batch3`, from `genQueueBatchFixtures.test.ts`.
/// Leaves 1111, 2222, 3333 from the genesis tree, batchSize 3, nZeroLeaves 7.
contract QueueStableBatch is BaseTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;

    QueuedMerkleTree internal qmt;
    IHasher internal hasher;

    function setUp() external {
        _setUp();
        hasher = _deployHasher();
        TransactionVerifierInfo[] memory none = new TransactionVerifierInfo[](0);
        Verifier verifier_ = new Verifier(
            none,
            address(new VerifierRegister()),
            address(new VerifierTreeUpdate()),
            address(this)
        );
        qmt.init(fixture.commitmentTreeQueueSize, hasher, verifier_);
    }

    function _queueBatch() internal {
        uint256[] memory leaves = new uint256[](3);
        leaves[0] = 1111;
        leaves[1] = 2222;
        leaves[2] = 3333;
        qmt.queueLeaves(leaves);
    }

    function _queueMore(uint256 n) internal {
        uint256[] memory more = new uint256[](n);
        for (uint256 i; i < n; ++i) more[i] = 9000 + i;
        qmt.queueLeaves(more);
    }

    /// Control: the fixture is a valid proof for exactly this queue.
    function test_batchProofVerifiesWhenQueueIsUnchanged() public {
        _queueBatch();
        TreeUpdateData memory d = _loadTreeUpdateData("poc_tree_update_batch3");
        assertEq(d.batchSize, 3, "fixture batchSize");

        qmt.update(d);

        assertEq(qmt.queueStartIndex, 3);
        assertEq(qmt.queueEndIndex, 3);
        assertEq(qmt.nextLeafIndex, 3);
    }

    /// One leaf queued after the proof was generated must not invalidate it.
    function test_proofSurvivesOneLaterEnqueue() public {
        _queueBatch();
        TreeUpdateData memory d = _loadTreeUpdateData("poc_tree_update_batch3");

        _queueMore(1);

        qmt.update(d);

        assertEq(qmt.queueStartIndex, 3, "only the proven batch is consumed");
        assertEq(qmt.queueEndIndex, 4, "the later leaf stays queued");
        assertEq(qmt.nextLeafIndex, 3);
        assertEq(qmt.queuedLeaves[3], 9000, "the later leaf is untouched");
    }

    /// More leaves than the circuit takes (queueSize = 10) queued afterwards: same result.
    function test_proofSurvivesManyLaterEnqueues() public {
        _queueBatch();
        TreeUpdateData memory d = _loadTreeUpdateData("poc_tree_update_batch3");

        _queueMore(12);

        qmt.update(d);

        assertEq(qmt.queueStartIndex, 3);
        assertEq(qmt.queueEndIndex, 15);
        assertEq(qmt.nextLeafIndex, 3);
    }

    /// The batch size is part of the proof. Claiming a different one fails verification,
    /// so the caller cannot use it to consume leaves the proof did not cover.
    function test_wrongBatchSizeFailsVerification() public {
        _queueBatch();
        _queueMore(1);
        TreeUpdateData memory d = _loadTreeUpdateData("poc_tree_update_batch3");
        d.batchSize = 4; // 4 <= pending, so the bounds pass; the proof covers 3.

        vm.expectRevert(QueuedMerkleTreeLogic.InvalidProof.selector);
        qmt.update(d);
    }

    /// `peekQueuedLeaves(n, nQueued)` returns `n` entries holding at most `nQueued` queued leaves.
    function test_peekQueuedLeavesNQueuedCapsRealLeaves() public {
        _queueBatch();
        _queueMore(2); // pending = 5

        uint256[] memory capped = qmt.peekQueuedLeaves(10, 3);
        assertEq(capped.length, 10);
        assertEq(capped[0], 1111);
        assertEq(capped[1], 2222);
        assertEq(capped[2], 3333);
        for (uint256 i = 3; i < 10; ++i) assertEq(capped[i], ZERO_LEAF, "padding");

        uint256[] memory all = qmt.peekQueuedLeaves(10, 10);
        assertEq(all[3], 9000, "nQueued above totalQueued returns every queued leaf");
        assertEq(all[4], 9001);
        assertEq(all[5], ZERO_LEAF);

        uint256[] memory narrow = qmt.peekQueuedLeaves(2, 10);
        assertEq(narrow.length, 2, "n still bounds the width");
    }

    /// The existing bounds are unchanged.
    function test_batchSizeBoundsStillApply() public {
        _queueBatch();
        TreeUpdateData memory d = _loadTreeUpdateData("poc_tree_update_batch3");

        d.batchSize = 4; // more than pending (3)
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidBatchSize.selector);
        qmt.update(d);

        d.batchSize = 0;
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidBatchSize.selector);
        qmt.update(d);
    }
}
