// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";

contract VerifierTest is BaseTest {
    Verifier internal _verifier;

    function setUp() public {
        VerifierTransact21 vt21 = new VerifierTransact21();
        VerifierTransact22 vt22 = new VerifierTransact22();
        TransactionVerifierInfo[] memory vInfos = new TransactionVerifierInfo[](
            2
        );
        vInfos[0] = TransactionVerifierInfo({
            id: 21,
            addr: address(vt21),
            selector: vt21.verifyProof.selector
        });
        vInfos[1] = TransactionVerifierInfo({
            id: 22,
            addr: address(vt22),
            selector: vt22.verifyProof.selector
        });
    }

    function test_getVerifierId() public view {
        uint256 id = _verifier.getTransactionVerifierId(2, 2);
        assertEq(id, 22);
    }
}
