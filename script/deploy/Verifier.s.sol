// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {Verifier} from "src/core/Verifier.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {Verifier42} from "src/verifiers/Verifier42.sol";
import {Verifier44} from "src/verifiers/Verifier44.sol";
import {Verifier82} from "src/verifiers/Verifier82.sol";
import {Verifier84} from "src/verifiers/Verifier84.sol";
import {VerifierInfo} from "src/core/Verifier.sol";
import {BaseScript} from "../BaseScript.sol";

contract VerifierDeploy is BaseScript {
    function run() external broadcast {
        Verifier22 v22 = new Verifier22();
        Verifier42 v42 = new Verifier42();
        Verifier44 v44 = new Verifier44();
        Verifier82 v82 = new Verifier82();
        Verifier84 v84 = new Verifier84();

        VerifierInfo[] memory vInfos = new VerifierInfo[](5);
        vInfos[0] = VerifierInfo({
            id: 22,
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        vInfos[1] = VerifierInfo({
            id: 42,
            addr: address(v42),
            selector: v42.verifyProof.selector
        });
        vInfos[2] = VerifierInfo({
            id: 44,
            addr: address(v44),
            selector: v44.verifyProof.selector
        });
        vInfos[3] = VerifierInfo({
            id: 82,
            addr: address(v82),
            selector: v82.verifyProof.selector
        });
        vInfos[4] = VerifierInfo({
            id: 84,
            addr: address(v84),
            selector: v84.verifyProof.selector
        });

        new Verifier(
            vInfos,
            _config.revokerPublicKey(),
            _config.encryptionPublicKey()
        );
    }
}
