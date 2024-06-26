// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {ZTransaction, ZTransactionType, ZTransactionLogic, RevokerData} from "../libraries/ZTransaction.sol";
import {MerkleTree} from "../libraries/MerkleTree.sol";

struct VerifierInfo {
    uint16 id;
    address addr;
    bytes4 selector;
}

contract Verifier is IVerifier {
    using ZTransactionLogic for ZTransaction;

    /**
     * @notice Verifier id to Verifier info mapping
     */
    mapping(uint256 => VerifierInfo) public verifiers;

    constructor(VerifierInfo[] memory vInfos) {
        uint256 len = vInfos.length;
        for (uint256 i = 0; i < len; ) {
            verifiers[vInfos[i].id] = vInfos[i];
            unchecked {
                ++i;
            }
        }
    }

    function verifyTransactionProof(
        ZTransaction memory ztx,
        RevokerData memory cKeys
    ) public view returns (bool) {
        VerifierInfo memory vInfo = getVerifier(
            ztx.nullifiers.length,
            ztx.commitments.length
        );

        if (vInfo.addr == address(0)) {
            revert("Verifier: verifier not found");
        }

        bytes memory vInp = ztx.toVerifierInput(cKeys, vInfo.selector);
        (bool success, bytes memory result) = vInfo.addr.staticcall(vInp);

        if (!success) {
            revert("Verification call failed");
        }

        return uint8(result[31]) == 1;
    }

    function getVerifier(
        uint256 nIns,
        uint256 nOuts
    ) public view returns (VerifierInfo memory) {
        return verifiers[getVerifierId(nIns, nOuts)];
    }

    function getVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) public pure returns (uint256 id) {
        return nIns * 10 + nOuts;
    }
}
