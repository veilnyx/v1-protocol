// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Verifier, VerifierInfo} from "src/core/Verifier.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {ZTransaction, ZTransactionType} from "src/libraries/ZTransaction.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";
import {BaseTest} from "test/fixtures/BaseTest.t.sol";

contract VerifierTest is BaseTest {
    Verifier internal _verifier;

    function setUp() public {
        Verifier22 verifier22 = new Verifier22();
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(verifier22),
            selector: verifier22.verifyProof.selector
        });
    }

    function test_getVerifierId() public view {
        uint256 id = _verifier.getVerifierId(2, 2);
        assertEq(id, 22);
    }
}
