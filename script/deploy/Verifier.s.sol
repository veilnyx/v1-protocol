// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2} from "forge-std/console2.sol";
import {BaseScript} from "../BaseScript.sol";
import {Verifier} from "src/core/Verifier.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {VerifierInfo} from "src/core/Verifier.sol";

contract VerifierDeploy is BaseScript {
    uint256 public constant REVOKER_PUBLIC_KEY_X =
        8116072818876777666029027213729376705234613448128995613697283149497235402123;
    uint256 public constant REVOKER_PUBLIC_KEY_Y =
        4598772416842731049226007701899382609184728232075557894618791492264594188716;

    uint256 public constant ENCRYPTION_PUBLIC_KEY_X =
        18136749973959690676930643759397962821618865161533601684883289116728073483917;
    uint256 public constant ENCRYPTION_PUBLIC_KEY_Y =
        7818464758266392754559612367237682152094555123891341826265694881788827476134;

    function run() external broadcast {
        Verifier22 v22 = new Verifier22();
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        new Verifier(
            vInfos,
            [REVOKER_PUBLIC_KEY_X, REVOKER_PUBLIC_KEY_Y],
            [ENCRYPTION_PUBLIC_KEY_X, ENCRYPTION_PUBLIC_KEY_Y]
        );
    }
}
