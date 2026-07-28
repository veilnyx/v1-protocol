// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {COMMITMENT_TREE_DEPTH, TREE_UPDATE_QUEUE_SIZE} from "src/base/Constants.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {MockVerifier} from "test/mocks/MockVerifier.sol";

/// Isolates the queue-accounting bug from the proof-length bug by using a
/// verifier that always returns true (i.e. assume the ZK proof is fully valid —
/// which it genuinely can be for these inputs, see report).
contract AuditQueueAccounting is BaseTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;

    QueuedMerkleTree internal qmt;
    QueuedMerkleTree internal qmtBadSize;
    MockVerifier internal mv;
    IHasher internal deployedHasher;

    function setUp() external {
        _setUp();
        mv = new MockVerifier();
        mv.setResult(true);
        deployedHasher = _deployHasher();
        qmt.init(fixture.commitmentTreeQueueSize, deployedHasher, IVerifier(address(mv)));
    }

    function test_queueStartIndexOverrunBricksPool() public {
        uint8 qs = qmt.queueSize;
        console2.log("queueSize:", qs);

        // Queue only 3 leaves...
        uint256[] memory few = new uint256[](3);
        few[0] = 111;
        few[1] = 222;
        few[2] = 333;
        qmt.queueLeaves(few);

        console2.log("queueStart:", qmt.queueStartIndex);
        console2.log("queueEnd:  ", qmt.queueEndIndex);

        // ...but claim a full batch. leaves[] handed to the circuit is
        // [111,222,333, ZERO_LEAF x7]; inserting ZERO_LEAF is a no-op for the
        // root, so an HONEST prover can satisfy the circuit with nZeroLeaves=0.
        uint256[COMMITMENT_TREE_DEPTH] memory subs;
        TreeUpdateData memory d = TreeUpdateData({
            newRoot: 12345,
            batchSize: qs, // == queueSize, so the `< queueSize` branch is skipped
            newLevelSubtrees: subs,
            proof: bytes("")
        });

        // REGRESSION (H-1): batchSize is now derived from queue state, so an
        // overstated value is rejected outright instead of corrupting the queue.
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidBatchSize.selector);
        qmt.update(d);

        // Queue accounting must be untouched, and QMT-1 (start <= end) must hold.
        assertLe(
            qmt.queueStartIndex,
            qmt.queueEndIndex,
            "invariant QMT-1 (start <= end) violated"
        );

        // Both reads that would have underflowed still work.
        qmt.getQueuedLeaves();
        this.simulatePrintNotes();
    }

    /// I-2: queueSize is fixed by the treeUpdate circuit's nLeaves parameter.
    /// Any other value silently changes the verifier calldata layout.
    function test_initRejectsQueueSizeMismatch() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                QueuedMerkleTreeLogic.InvalidQueueSize.selector,
                uint8(9),
                TREE_UPDATE_QUEUE_SIZE
            )
        );
        qmtBadSize.init(9, deployedHasher, IVerifier(address(mv)));
    }

    function simulatePrintNotes() external view returns (uint32) {
        return qmt.nextLeafIndex + (qmt.queueEndIndex - qmt.queueStartIndex);
    }
}
