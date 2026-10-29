// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddressLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {FIELD_SIZE} from "src/base/Constants.sol";
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
    uint256 constant BASE8_X = 5299619240641551281634865583518297030282874472190772894086521144482721001553;
    uint256 constant BASE8_Y = 16950150798460657717958625567821834550301663161624707787222815936182638968203;

    /// The register circuit does not validate the two public keys; the pool rejects off-curve
    /// and degenerate (x == 0) keys before verifying anything.
    function test_registerRejectsInvalidPublicKeys() public {
        bytes memory honest = regData.shieldedAddress;
        uint256[4] memory slot = [uint256(32), 64, 96, 128];
        for (uint256 k; k < 4; ++k) {
            bytes memory bad = bytes.concat(honest);
            // off-curve: bump one coordinate by one
            uint256 v = uint256(_word(bad, slot[k])) + 1;
            _setWord(bad, slot[k], v);
            ShieldedAddressRegistrationData memory r = regData;
            r.shieldedAddress = bad;
            r.signature = _getRegisterAddressSignature(attackerPK, bad);
            try pool.registerAddress(r) {
                fail();
            } catch (bytes memory err) {
                assertEq(bytes4(err), IPool.InvalidCurvePoint.selector);
            }
        }
        // the order-2 point (0, -1) is on the curve but degenerate
        for (uint256 k; k < 2; ++k) {
            bytes memory bad = bytes.concat(honest);
            _setWord(bad, 32 + 64 * k, 0);
            _setWord(bad, 64 + 64 * k, FIELD_SIZE - 1);
            ShieldedAddressRegistrationData memory r = regData;
            r.shieldedAddress = bad;
            r.signature = _getRegisterAddressSignature(attackerPK, bad);
            vm.expectRevert(abi.encodeWithSelector(IPool.InvalidCurvePoint.selector, 0, FIELD_SIZE - 1));
            pool.registerAddress(r);
        }
    }

    function _word(bytes memory b, uint256 off) internal pure returns (bytes32 w) {
        assembly {
            w := mload(add(add(b, 32), off))
        }
    }

    function _setWord(bytes memory b, uint256 off, uint256 v) internal pure {
        assembly {
            mstore(add(add(b, 32), off), v)
        }
    }

    function test_registerArbitraryShieldedAddress() public {
        // honest public signals = the real 160-byte shieldedAddress
        bytes memory honestSignals = abi.encodePacked(
            fixture.sender.rootAddress,
            fixture.sender.signPublicKey,
            fixture.sender.viewPublicKey
        );
        assertEq(honestSignals.length, 160);

        // Attacker's fabricated address: no known private key. The two public keys are valid
        // curve points (BabyJubJub Base8) so the registration gets past the key checks and
        // reaches the proof-length check this test is about.
        bytes memory fakeAddress = abi.encodePacked(
            uint256(0xBADC0DE), // rootAddress
            BASE8_X,
            BASE8_Y,
            BASE8_X,
            BASE8_Y
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
