// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {DeployScript} from "./DeployScript.sol";
import {Verifier} from "src/core/Verifier.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {VerifierInfo} from "src/libraries/DataTypes.sol";

contract VerifierDeploy is DeployScript {
    function _deploy() internal override {
        Verifier22 v22 = new Verifier22();
        uint256[] memory ids = new uint256[](1);
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        ids[0] = 2 * 10 + 2;
        vInfos[0] = VerifierInfo({
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        new Verifier(ids, vInfos);
    }
}
