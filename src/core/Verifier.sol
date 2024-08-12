// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {VerifierRegister} from "../verifiers/VerifierRegister.sol";
import {ZTransaction, ZTransactionType, ZTransactionLogic, RevokerData} from "../libraries/ZTransaction.sol";
import {MerkleTree} from "../libraries/MerkleTree.sol";

struct TransactionVerifierInfo {
    uint16 id;
    bytes4 selector;
    address addr;
}

contract Verifier is IVerifier {
    using ZTransactionLogic for ZTransaction;

    /**
     * @notice Verifier id to Verifier info mapping
     */
    address internal _addressVerifier;
    mapping(uint256 => TransactionVerifierInfo) internal _transactionVerifiers;

    constructor(
        TransactionVerifierInfo[] memory txvInfos,
        address addressVerifier
    ) {
        uint256 len = txvInfos.length;

        for (uint8 i = 0; i < len; ) {
            _transactionVerifiers[txvInfos[i].id] = txvInfos[i];
            unchecked {
                ++i;
            }
        }

        _addressVerifier = addressVerifier;
    }

    function verifyAddressProof(
        bytes calldata vParams
    ) public view returns (bool) {
        (bool success, bytes memory result) = _addressVerifier.staticcall(
            bytes.concat(VerifierRegister.verifyProof.selector, vParams)
        );

        if (!success) {
            revert("Verification call failed");
        }

        return uint8(result[31]) == 1;
    }

    function verifyTransactionProof(
        uint16 vId,
        bytes calldata vParams
    ) public view returns (bool) {
        TransactionVerifierInfo memory vInfo = _transactionVerifiers[vId];

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

    function getTransactionVerifier(
        uint16 vId
    ) public view returns (TransactionVerifierInfo memory) {
        return _transactionVerifiers[vId];
    }

    function getTransactionVerifierId(
        uint256 nIns,
        uint256 nOuts
    ) public pure returns (uint16 id) {
        return uint16(nIns * 10 + nOuts);
    }
}
