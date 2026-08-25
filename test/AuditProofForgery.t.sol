// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console2} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {ShieldedTransaction, ShieldedTransactionType, RevokerData, ShieldedTransactionLogic} from "src/libraries/ShieldedTransactionLogic.sol";

/// Helper to reach the `calldata`-only library entrypoint.
contract InputBuilder {
    function build(
        ShieldedTransaction calldata stx,
        RevokerData memory rd
    ) external pure returns (bytes memory) {
        return ShieldedTransactionLogic.toVerifierInput(stx, rd);
    }
}

contract AuditProofForgery is PoolTest {
    InputBuilder builder;

    function setUp() public {
        _setUp();
        builder = new InputBuilder();
    }

    /// Demonstrates that `stx.proof` length is unvalidated, so an attacker can
    /// embed the 12 public signals of a *legitimate* proof inside the proof blob.
    /// The contract's honestly-computed public inputs are appended AFTER and are
    /// silently ignored by the Solidity ABI decoder -> the verifier validates the
    /// attacker's chosen statement while the Pool acts on totally different data.
    function test_forgeTransactWithMutatedFields() public {
        _mintAsset(asset1, address(this), 100000 ether);
        _mintAsset(asset2, address(this), 100000e6);
        _approveAsset(asset1, address(pool), 100000 ether);
        _approveAsset(asset2, address(pool), 100000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        // 1. Grab the HONEST public inputs the contract would compute for this tx.
        RevokerData memory rd = pool.getRevokerData(stx.revokerId);
        bytes memory honestVInp = builder.build(stx, rd);

        console2.log("honest vInp length:", honestVInp.length);
        console2.log("original proof length:", stx.proof.length);

        // honestVInp = proof(256) || 12 public signals (384) = 640
        assertEq(honestVInp.length, 640, "expected 8+12 words");

        // 2. Attacker repackages: proof' := proof || realPublicSignals (640 bytes).
        bytes memory forgedProof = honestVInp;

        // 3. Attacker mutates every field the Pool acts on but which now no longer
        //    reaches the verifier. Change commitments (mint arbitrary notes) and
        //    nullifiers (arbitrary values), and the fee data.
        ShieldedTransaction memory evil = stx;
        evil.proof = forgedProof;
        for (uint256 i = 0; i < evil.commitments.length; i++) {
            evil.commitments[i] = uint256(
                keccak256(abi.encode("attacker-note", i))
            ) % 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        }
        for (uint256 i = 0; i < evil.nullifiers.length; i++) {
            evil.nullifiers[i] = uint256(
                keccak256(abi.encode("attacker-nullifier", i))
            ) % 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        }
        // Also tamper the memo blob (feeds alpha/gamma) to prove UHF is bypassed.
        evil.notesMemo = abi.encodePacked(evil.notesMemo);
        evil.refundAddress = 12345;

        // 4. The forged transaction is accepted.
        // REGRESSION (C-1): must revert now that vParams length is enforced.
        vm.expectRevert(bytes("Verifier: invalid proof length"));
        pool.transact(evil);

        console2.log("FORGED TRANSACTION ACCEPTED");
    }

    /// Control: the same mutation WITHOUT the oversized-proof trick must revert.
    function test_control_mutationRejectedWithNormalProof() public {
        _mintAsset(asset1, address(this), 100000 ether);
        _mintAsset(asset2, address(this), 100000e6);
        _approveAsset(asset1, address(pool), 100000 ether);
        _approveAsset(asset2, address(pool), 100000e6);

        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        for (uint256 i = 0; i < stx.commitments.length; i++) {
            stx.commitments[i] = uint256(
                keccak256(abi.encode("attacker-note", i))
            ) % 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        }
        vm.expectRevert();
        pool.transact(stx);
    }
}
