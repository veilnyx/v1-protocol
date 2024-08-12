// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {Verifier} from "src/core/Verifier.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {TransactionVerifierInfo} from "src/core/Verifier.sol";
import {BaseScript} from "../BaseScript.sol";

contract VerifierDeploy is BaseScript {
    function run() external broadcast {
        VerifierTransact21 vt21 = new VerifierTransact21();
        VerifierTransact22 vt22 = new VerifierTransact22();
        VerifierRegister vr = new VerifierRegister();

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

        new Verifier(vInfos, address(vr));
    }
}
