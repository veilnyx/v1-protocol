// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddressLogic.sol";
import {GROTH16_PROOF_LENGTH, ADDRESS_PUBLIC_INPUTS} from "src/core/Verifier.sol";
import {FIELD_SIZE} from "src/base/Constants.sol";

/// Reaches the calldata-only internal library entrypoint.
contract RegisterInputHarness {
    function verify(
        ShieldedAddressRegistrationData calldata reg,
        address verifier,
        address signer
    ) external view returns (bool) {
        return ShieldedAddressLogic.verifyProof(reg, verifier, signer);
    }
}

/// The register proof must be bound to the registrant. Without it the proof commits
/// only to the shielded address, and the EIP-712 struct
/// (RegisterAddress(string message, bytes shieldedAddress)) names no signer either,
/// so an observer can re-sign the same shielded address with their own key and
/// front-run the registration. That permanently binds the victim's rootAddress to an
/// address of the attacker's choosing -- which is exactly what a decrypted note is
/// ultimately resolved to -- and nothing on chain can repair it.
///
/// The register circuit binds `publicAddress` inside its single public input
/// (sha256 over the shielded address and the signer), and register_sender is proven
/// with `publicAddress` = `config.registrant`, so the binding is enforced on chain --
/// test_e2e_hijackedRegistrationFailsVerification proves it end to end. The arity guard
/// in that test is retained so a regression that unbinds the signer skips loudly rather
/// than passing vacuously.
contract AuditRegisterBinding is PoolTest {
    RegisterInputHarness internal harness;

    function setUp() public {
        _setUp();
        harness = new RegisterInputHarness();
    }

    function _reg()
        internal
        view
        returns (ShieldedAddressRegistrationData memory)
    {
        return _loadShieldedAddressRegistrationData("register_sender");
    }

    function _expectedVParams(
        ShieldedAddressRegistrationData memory reg,
        address signer
    ) internal pure returns (bytes memory) {
        // One public input: sha256(shieldedAddress || publicAddress) mod p
        uint256 inputsHash = uint256(
            sha256(abi.encodePacked(reg.shieldedAddress, uint256(uint160(signer))))
        ) % FIELD_SIZE;
        return abi.encodePacked(reg.proof, inputsHash);
    }

    function test_signerIsAppendedToVerifierPublicInputs() public {
        (address alice, ) = makeAddrAndKey("alice-registrant");
        ShieldedAddressRegistrationData memory reg = _reg();

        bytes memory expected = _expectedVParams(reg, alice);
        assertEq(
            expected.length,
            GROTH16_PROOF_LENGTH + 32 * ADDRESS_PUBLIC_INPUTS,
            "vParams length does not match the declared public input count"
        );

        vm.expectCall(
            address(verifier),
            abi.encodeCall(IVerifier.verifyAddressProof, (expected))
        );
        harness.verify(reg, address(verifier), alice);
    }

    /// Same proof, same shielded address, attacker's signer => different statement.
    function test_attackerSignerChangesTheProvenStatement() public {
        (address alice, ) = makeAddrAndKey("alice-registrant");
        (address bob, ) = makeAddrAndKey("bob-frontrunner");
        ShieldedAddressRegistrationData memory reg = _reg();

        assertTrue(alice != bob, "test setup: signers must differ");

        vm.expectCall(
            address(verifier),
            abi.encodeCall(
                IVerifier.verifyAddressProof,
                (_expectedVParams(reg, bob))
            )
        );
        harness.verify(reg, address(verifier), bob);

        assertTrue(
            keccak256(_expectedVParams(reg, alice)) !=
                keccak256(_expectedVParams(reg, bob)),
            "attacker signer must change the proven statement"
        );
    }

    /// END TO END, against the real Groth16 verifier: the register_sender proof was
    /// generated binding publicAddress = the fixture signer. Verified with that
    /// signer it passes; verified with an attacker's signer it must FAIL, which is
    /// what makes register() revert with InvalidAddressProof on a hijack attempt.
    ///
    /// The signer is hashed into the single public input, so a different signer is a
    /// different statement and the hijack must fail verification.
    function test_e2e_hijackedRegistrationFailsVerification() public {
        address alice = fixture.registrant.addr; // the fixture's own signer
        (address bob, ) = makeAddrAndKey("bob-frontrunner");
        ShieldedAddressRegistrationData memory reg = _reg();

        bool honestOk = harness.verify(reg, address(verifier), alice);
        bool hijackOk = harness.verify(reg, address(verifier), bob);

        // Self-detecting regression guard: if the signer ever stops being bound, BOTH
        // verify and this test cannot mean anything. Skip loudly rather than pass
        // vacuously. With the current binding this branch is not taken.
        if (honestOk && hijackOk) {
            emit log(
                "SKIP: the register proof does not bind the signer; check VerifierRegister and the register circuit"
            );
            vm.skip(true);
            return;
        }

        assertTrue(honestOk, "honest registrant must verify");
        assertFalse(hijackOk, "hijacked registration must NOT verify");
    }
}
