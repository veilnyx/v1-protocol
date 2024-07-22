// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {ZTransaction, ZTransactionType, ZTransactionLogic, RevokerData} from "../libraries/ZTransaction.sol";
import {MerkleTree} from "../libraries/MerkleTree.sol";

struct VerifierInfo {
    uint16 id;
    bytes4 selector;
    address addr;
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
        uint16 vId,
        bytes calldata vParams
    ) public view returns (bool) {
        VerifierInfo memory vInfo = verifiers[vId];

        if (vInfo.addr == address(0)) {
            revert("Verifier: verifier not found");
        }

        (bool success, bytes memory result) = vInfo.addr.staticcall(
            bytes.concat(vInfo.selector, vParams)
        );

        if (!success) {
            revert("Verification call failed");
        }

        return uint8(result[31]) == 1;
    }

    function getVerifier(uint16 vId) public view returns (VerifierInfo memory) {
        return verifiers[vId];
    }

    function getVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) public pure returns (uint16 id) {
        return uint16(nIns * 10 + nOuts);
    }
}
