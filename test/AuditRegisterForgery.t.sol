// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddressLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolBaseTest} from "test/fixtures/PoolBaseTest.sol";

contract AuditRegisterForgery is PoolBaseTest {
    ShieldedAddressRegistrationData regData;
    address attackerAddr;
    uint256 attackerPK;

    function setUp() public {
        _setUp();
        (attackerAddr, attackerPK) = makeAddrAndKey("attacker");
        regData = _loadShieldedAddressRegistrationData("register_sender");
    }

    /// Register an ARBITRARY shielded address (no knowledge of its private keys)
    /// by padding `proof` with the honest 5 public signals; the real
    /// `shieldedAddress` bytes become ignored trailing calldata.
    function test_registerArbitraryShieldedAddress() public {
        // honest public signals = the real 160-byte shieldedAddress
        bytes memory honestSignals = abi.encodePacked(
            fixture.sender.rootAddress,
            fixture.sender.signPublicKey,
            fixture.sender.viewPublicKey
        );
        assertEq(honestSignals.length, 160);

        // Attacker's fabricated address: pure garbage, no known private key.
        bytes memory fakeAddress = abi.encodePacked(
            uint256(0xBADC0DE), // rootAddress
            uint256(1),
            uint256(2),
            uint256(3),
            uint256(4)
        );

        ShieldedAddressRegistrationData memory evil;
        evil.proof = abi.encodePacked(regData.proof, honestSignals); // 416 bytes
        evil.shieldedAddress = fakeAddress;
        evil.signature = _getRegisterAddressSignature(attackerPK, fakeAddress);

        console2.log("original proof len:", regData.proof.length);
        console2.log("forged proof len:", evil.proof.length);

        // REGRESSION (C-1): the fabricated rootAddress must NOT be insertable.
        vm.expectRevert(bytes("Verifier: invalid proof length"));
        pool.registerAddress(evil);
    }

    /// Control: same fabricated address with a normal-length proof is rejected.
    function test_control_fakeAddressRejected() public {
        bytes memory fakeAddress = abi.encodePacked(
            uint256(0xBADC0DE),
            uint256(1),
            uint256(2),
            uint256(3),
            uint256(4)
        );
        ShieldedAddressRegistrationData memory evil;
        evil.proof = regData.proof;
        evil.shieldedAddress = fakeAddress;
        evil.signature = _getRegisterAddressSignature(attackerPK, fakeAddress);

        vm.expectRevert();
        pool.registerAddress(evil);
    }
}
