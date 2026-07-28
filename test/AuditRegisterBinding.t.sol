// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddressLogic.sol";
import {GROTH16_PROOF_LENGTH, ADDRESS_PUBLIC_INPUTS} from "src/core/Verifier.sol";

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
/// NOTE: the committed VerifierRegister still declares uint256[5]. Until it is
/// regenerated from the 6-input register circuit, the appended word is trailing
/// calldata and the binding is INERT. These tests are what proves the contract side
/// is wired correctly in the meantime; a green full suite does not.
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
        return
            abi.encodePacked(
                reg.proof,
                reg.shieldedAddress,
                uint256(uint160(signer))
            );
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
}
