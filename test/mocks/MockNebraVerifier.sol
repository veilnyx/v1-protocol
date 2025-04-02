// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {INebraUpa} from "src/interfaces/INebraUpa.sol";

contract MockNebraVerifier is INebraUpa {
    bool public isProofVerifiedResult;

    function setIsProofVerifiedResult(bool _isProofVerifiedResult) external {
        isProofVerifiedResult = _isProofVerifiedResult;
    }

    function isProofVerified(
        bytes32 /* proofId */
    ) external view override returns (bool) {
        return isProofVerifiedResult;
    }
}
