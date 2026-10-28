// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console2} from "forge-std/console2.sol";
import {BaseScript} from "../BaseScript.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTransact42} from "src/verifiers/VerifierTransact42.sol";

contract AddTransact42Verifier is BaseScript {
    // Matches getTransactionVerifierId(4, 2): 4 * 10^1 + 2 = 42
    uint16 constant VERIFIER_ID = 42;

    function run() external broadcast {
        Verifier verifier = Verifier(vm.envAddress("VERIFIER_ADDRESS"));

        VerifierTransact42 vt42 = new VerifierTransact42();
        console2.log("VerifierTransact42 deployed at:", address(vt42));

        verifier.addTransactionVerifier(
            TransactionVerifierInfo({
                id: VERIFIER_ID,
                addr: address(vt42),
                selector: vt42.verifyProof.selector
            })
        );

        console2.log("TransactionVerifier id=%d registered", VERIFIER_ID);
    }
}
