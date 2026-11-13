// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "src/interfaces/IPool.sol";
import {IHasher} from "src/interfaces/IHasher.sol";
import {ShieldedTransaction, ShieldedTransactionType, RevokerData, ShieldedTransactionLogic} from "src/libraries/ShieldedTransactionLogic.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {FIELD_SIZE, ZERO_LEAF, MERKLE_TREE_DEPTH, COMMITMENT_TREE_DEPTH} from "src/base/Constants.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

/// Reaches the calldata-only library entrypoint the pool uses to build verifier input.
contract InputBuilder {
    function build(ShieldedTransaction calldata stx, RevokerData memory rd)
        external
        pure
        returns (bytes memory)
    {
        return ShieldedTransactionLogic.toVerifierInput(stx, rd);
    }
}

/// Attack suite for the HyperEVM public-input cut (12/6/64 -> 3/1/1).
///
/// The 9 values that used to be separate transact public inputs (roots, tx hash, pubFlow,
/// revoker keys, refundAddress) are now bound ONLY through the UHF (alpha, beta, gamma).
/// Each test takes a valid, real-proof transaction and changes one bound value the way an
/// attacker or a misconfigured pool could, then requires the pool to reject it. If a value
/// were left out of the binding, the matching test would let the transaction through.
contract InputCutBindingTest is PoolTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;

    ShieldedTransaction internal stx;
    InputBuilder internal builder;

    function setUp() public {
        _setUp();
        _makePreDeposit();
        builder = new InputBuilder();
        stx = _loadShieldedTransaction("transfer_20_weth_without_fee");
    }

    function _expectProofRejected() internal {
        vm.expectRevert(IPool.InvalidTransactionProof.selector);
        pool.transact(stx);
    }

    /// Root of an empty tree of `depth` levels (always a known root: roots[0] at init).
    function _emptyRoot(uint256 depth) internal returns (uint256 z) {
        IHasher hasher = _deployHasher();
        z = ZERO_LEAF;
        for (uint256 i = 0; i < depth; i++) {
            z = hasher.hash([z, z]);
        }
    }

    // ------------------------------------------------------------------ control

    function test_control_honestTransferIsAccepted() external {
        pool.transact(stx);
    }

    // --------------------------------------------- the 9 header values (transact)

    /// header[0]: a different, still KNOWN address-tree root.
    function test_rejects_otherKnownAddressTreeRoot() external {
        uint256 other = _emptyRoot(MERKLE_TREE_DEPTH);
        assertTrue(other != stx.addressTreeRoot, "setup: roots must differ");
        assertTrue(pool.isKnownAddressTreeRoot(other), "setup: root must be known");
        stx.addressTreeRoot = other;
        _expectProofRejected();
    }

    /// header[1]: a different, still KNOWN commitment-tree root (spending against a
    /// tree the notes are not in).
    function test_rejects_otherKnownCommitmentTreeRoot() external {
        uint256 other = _emptyRoot(COMMITMENT_TREE_DEPTH);
        assertTrue(other != stx.commitmentTreeRoot, "setup: roots must differ");
        assertTrue(pool.isKnownCommitmentTreeRoot(other), "setup: root must be known");
        stx.commitmentTreeRoot = other;
        _expectProofRejected();
    }

    /// header[2]: anything the signed hash covers (here keysMemo) changes the hash.
    function test_rejects_changedSignedHash() external {
        stx.keysMemo = abi.encodePacked(stx.keysMemo, bytes1(0x01));
        _expectProofRejected();
    }

    /// header[3]: pubFlow follows txType. A transfer replayed as a withdrawal must fail.
    function test_rejects_flippedPubFlow() external {
        stx.txType = ShieldedTransactionType.WITHDRAW;
        _expectProofRejected();
    }

    /// header[4..8] in isolation, straight against the real verifier: the pool registry
    /// forbids reusing a revoker key, so a pool-level test cannot change ONE of these alone.
    /// Each case builds the verifier input exactly as the pool does, with one key changed.
    function _verifiesWith(RevokerData memory rd) internal view returns (bool) {
        uint16 vId = verifier.getTransactionVerifierId(stx.nullifiers.length, stx.commitments.length);
        return IVerifier(address(verifier)).verifyTransactionProof(vId, builder.build(stx, rd));
    }

    function test_control_directVerifyWithRegistryKeys() external view {
        assertTrue(_verifiesWith(pool.getRevokerData(stx.revokerId)), "honest input must verify");
    }

    /// The compliance binding: a proof made for another revoker key must not verify.
    function test_rejects_otherRevokerPublicKey_x() external view {
        RevokerData memory rd = pool.getRevokerData(stx.revokerId);
        rd.revokerPublicKey[0] = fixture.encryptionPublicKey[0];
        assertFalse(_verifiesWith(rd));
    }

    function test_rejects_otherRevokerPublicKey_y() external view {
        RevokerData memory rd = pool.getRevokerData(stx.revokerId);
        rd.revokerPublicKey[1] = fixture.encryptionPublicKey[1];
        assertFalse(_verifiesWith(rd));
    }

    function test_rejects_otherEncryptionPublicKey_x() external view {
        RevokerData memory rd = pool.getRevokerData(stx.revokerId);
        rd.encryptionPublicKey[0] = fixture.revokerPublicKey[0];
        assertFalse(_verifiesWith(rd));
    }

    function test_rejects_otherEncryptionPublicKey_y() external view {
        RevokerData memory rd = pool.getRevokerData(stx.revokerId);
        rd.encryptionPublicKey[1] = fixture.revokerPublicKey[1];
        assertFalse(_verifiesWith(rd));
    }

    /// Pool level: a second revoker (different keys) cannot be swapped in for the one the
    /// proof was made for. revokerId is not in the legacy signed hash, so only the header
    /// keys change.
    function test_rejects_swappedRevokerId() external {
        pool.registerRevoker(fixture.encryptionPublicKey, fixture.revokerPublicKey, revokerMetaData);
        stx.revokerId = 1;
        _expectProofRejected();
    }

    /// header[6]: refundAddress.
    function test_rejects_changedRefundAddress() external {
        stx.refundAddress = (stx.refundAddress + 1) % FIELD_SIZE;
        _expectProofRejected();
    }

    /// header[6], aliased: refundAddress + p would reduce to the same value inside gamma.
    /// It must be rejected outright (it used to be range-checked as a public input).
    function test_rejects_nonCanonicalRefundAddress() external {
        uint256 aliased = stx.refundAddress + FIELD_SIZE;
        stx.refundAddress = aliased;
        vm.expectRevert(abi.encodeWithSelector(IPool.NonCanonicalFieldElement.selector, aliased));
        pool.transact(stx);
    }

    /// The prover-supplied beta must be the Poseidon chain the circuit enforces.
    function test_rejects_tamperedBeta() external {
        stx.betaUHF = (stx.betaUHF + 1) % FIELD_SIZE;
        _expectProofRejected();
    }

}

/// Tree update: one public input, sha256(leafIndex || leaves || lastRoot || newRoot ||
/// nZeroLeaves) mod p, with the subtrees a private witness bound to the stored root.
contract InputCutTreeUpdateBindingTest is PoolTest {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;

    QueuedMerkleTree internal qmt;

    function setUp() public {
        _setUp();
        IHasher hasher = _deployHasher();
        Verifier verifier_ = new Verifier(
            new TransactionVerifierInfo[](0),
            address(new VerifierRegister()),
            address(new VerifierTreeUpdate()),
            address(this)
        );
        qmt.init(fixture.commitmentTreeQueueSize, hasher, verifier_);
        qmt.queueLeaves(fixture.leavesQueue1);
    }

    function test_control_honestUpdateIsAccepted() external {
        TreeUpdateData memory d = _loadTreeUpdateData("tree_update_data_1");
        qmt.update(d);
        (, uint256 root, , ) = qmt.getState();
        assertEq(root, d.newRoot, "root not updated");
    }

    function test_rejects_forgedNewRoot() external {
        TreeUpdateData memory d = _loadTreeUpdateData("tree_update_data_1");
        d.newRoot = (d.newRoot + 1) % FIELD_SIZE;
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidProof.selector);
        qmt.update(d);
    }

    /// A smaller batch changes nZeroLeaves (and the leaves after it become ZERO_LEAF).
    function test_rejects_changedBatchSize() external {
        TreeUpdateData memory d = _loadTreeUpdateData("tree_update_data_1");
        d.batchSize = d.batchSize - 1;
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidProof.selector);
        qmt.update(d);
    }

    /// The same proof replayed after the tree moved: leafIndex and lastRoot differ.
    function test_rejects_replayAfterUpdate() external {
        TreeUpdateData memory d = _loadTreeUpdateData("tree_update_data_1");
        qmt.update(d);
        qmt.queueLeaves(fixture.leavesQueue1);
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidProof.selector);
        qmt.update(d);
    }
}
