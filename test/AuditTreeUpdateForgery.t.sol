// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHasher} from "src/interfaces/IHasher.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {COMMITMENT_TREE_DEPTH} from "src/base/Constants.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {console2} from "forge-std/console2.sol";

contract AuditTreeUpdateForgery is BaseTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;

    QueuedMerkleTree internal qmt;
    IHasher internal hasher;

    function setUp() external {
        _setUp();
        hasher = _deployHasher();
        VerifierTreeUpdate treeUpdateVerifier = new VerifierTreeUpdate();
        TransactionVerifierInfo[]
            memory txvInfos = new TransactionVerifierInfo[](0);
        Verifier verifier_ = new Verifier(
            txvInfos,
            address(new VerifierRegister()),
            address(treeUpdateVerifier),
            address(this)
        );
        qmt.init(hasher, verifier_);
    }

    /// Anyone can set the commitment tree root to an ARBITRARY value by padding
    /// `TreeUpdateData.proof` with the honest public signals; the contract's own
    /// computed signals (including its `newRoot`) become ignored trailing calldata.
    function test_arbitraryRootInsertion() public {
        qmt.queueLeaves(fixture.leavesQueue1);
        TreeUpdateData memory d = _loadTreeUpdateData("tree_update_data_1");

        // Rebuild the exact vParams _verifyUpdateProof would produce (honest case).
        (
            uint256[] memory leaves,
            uint256[COMMITMENT_TREE_DEPTH] memory subtrees,
            uint256 lastRoot,
            ,

        ) = qmt.getState();

        uint256 nZero = d.batchSize < qmt.queueSize
            ? qmt.queueSize - d.batchSize
            : 0;

        bytes memory honest = abi.encodePacked(
            d.proof,
            uint256(qmt.nextLeafIndex),
            leaves,
            lastRoot,
            subtrees,
            d.newRoot,
            d.newLevelSubtrees,
            nZero
        );
        console2.log("honest vParams length:", honest.length);
        console2.log("proof length:", d.proof.length);
        assertEq(honest.length, 256 + 64 * 32);

        // Attacker: proof' := proof || honest 64 public signals; newRoot := anything.
        d.proof = honest;
        d.newRoot = uint256(keccak256("attacker controlled root"));

        // REGRESSION (C-1): must revert now that vParams length is enforced.
        vm.expectRevert(bytes("Verifier: invalid proof length"));
        qmt.update(d);

        // The tree must be untouched by the rejected attempt: still the pre-update root,
        // and in particular NOT the attacker's chosen value.
        (, , uint256 rootAfter, , ) = qmt.getState();
        assertEq(rootAfter, lastRoot, "root changed despite rejection");
        assertTrue(
            rootAfter != uint256(keccak256("attacker controlled root")),
            "attacker root was inserted"
        );
    }
}
