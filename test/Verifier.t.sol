// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Verifier, VerifierInfo} from "src/core/Verifier.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {ZTransaction, ZTransactionType} from "src/libraries/ZTransaction.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";
import {ZKFi, ZAccount} from "test/helpers/ZKFi.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";

contract VerifierTest is BaseTest {
    Verifier internal _verifier;

    function setUp() public {
        // _initFixture();
        Verifier22 verifier22 = new Verifier22();
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(verifier22),
            selector: verifier22.verifyProof.selector
        });
        _verifier = new Verifier(
            vInfos,
            fixture.revokerPublicKey,
            fixture.encryptionPublicKey
        );
    }

    function test_PublicKeys() public view {
        (uint256 revKeyX, uint256 revKeyY) = _verifier.getRevokerPublicKey();
        (uint256 encKeyX, uint256 encKeyY) = _verifier.getEncryptionPublicKey();
        assertEq(revKeyX, fixture.revokerPublicKey[0]);
        assertEq(revKeyY, fixture.revokerPublicKey[1]);
        assertEq(encKeyX, fixture.encryptionPublicKey[0]);
        assertEq(encKeyY, fixture.encryptionPublicKey[1]);
    }

    function test_getVerifierId() public view {
        uint256 id = _verifier.getVerifierId(2, 2);
        assertEq(id, 22);
    }
}
