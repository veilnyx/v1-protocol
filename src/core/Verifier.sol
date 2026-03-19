// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {VerifierRegister} from "../verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "../verifiers/VerifierTreeUpdate.sol";
import {MerkleTree} from "../libraries/MerkleTree.sol";

struct TransactionVerifierInfo {
    uint16 id;
    bytes4 selector;
    address addr;
}

contract Verifier is IVerifier, Ownable {
    /**
     * @notice Verifier id to Verifier info mapping for transaction verifiers only
     */
    mapping(uint256 => TransactionVerifierInfo) internal _transactionVerifiers;
    address internal _addressVerifier;
    address internal _treeUpdateVerifier;

    event TransactionVerifierAdded(
        uint16 indexed id,
        bytes4 selector,
        address addr
    );
    event TransactionVerifierRemoved(uint16 indexed id);

    error ZeroAddress();
    error VerifierAlreadyExists(uint16 id);

    constructor(
        TransactionVerifierInfo[] memory txvInfos,
        address addressVerifier,
        address treeUpdateVerifier
    ) Ownable(msg.sender) {
        if (addressVerifier == address(0) || treeUpdateVerifier == address(0))
            revert ZeroAddress();

        uint256 len = txvInfos.length;

        for (uint256 i = 0; i < len; ) {
            if (txvInfos[i].addr == address(0)) revert ZeroAddress();
            _transactionVerifiers[txvInfos[i].id] = txvInfos[i];
            unchecked {
                ++i;
            }
        }

        _addressVerifier = addressVerifier;
        _treeUpdateVerifier = treeUpdateVerifier;
    }

    /// @notice Adds a new transaction verifier
    /// @dev Only callable by owner
    /// @param txvInfo The transaction verifier info to add
    function addTransactionVerifier(
        TransactionVerifierInfo calldata txvInfo
    ) external onlyOwner {
        if (txvInfo.addr == address(0)) revert ZeroAddress();
        if (_transactionVerifiers[txvInfo.id].addr != address(0)) {
            revert VerifierAlreadyExists(txvInfo.id);
        }

        _transactionVerifiers[txvInfo.id] = txvInfo;
        emit TransactionVerifierAdded(
            txvInfo.id,
            txvInfo.selector,
            txvInfo.addr
        );
    }

    /// @notice Adds multiple transaction verifiers in batch
    /// @dev Only callable by owner
    /// @param txvInfos Array of transaction verifier infos to add
    function addTransactionVerifiers(
        TransactionVerifierInfo[] calldata txvInfos
    ) external onlyOwner {
        uint256 len = txvInfos.length;

        for (uint256 i = 0; i < len; ) {
            if (txvInfos[i].addr == address(0)) revert ZeroAddress();
            if (_transactionVerifiers[txvInfos[i].id].addr != address(0)) {
                revert VerifierAlreadyExists(txvInfos[i].id);
            }

            _transactionVerifiers[txvInfos[i].id] = txvInfos[i];
            emit TransactionVerifierAdded(
                txvInfos[i].id,
                txvInfos[i].selector,
                txvInfos[i].addr
            );

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Removes a transaction verifier
    /// @dev Only callable by owner
    /// @param vId The verifier ID to remove
    function removeTransactionVerifier(uint16 vId) external onlyOwner {
        if (_transactionVerifiers[vId].addr == address(0)) {
            revert("Verifier: verifier not found");
        }

        delete _transactionVerifiers[vId];
        emit TransactionVerifierRemoved(vId);
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

    function verifyTreeUpdateProof(
        bytes calldata vParams
    ) public view returns (bool) {
        (bool success, bytes memory result) = _treeUpdateVerifier.staticcall(
            bytes.concat(VerifierTreeUpdate.verifyProof.selector, vParams)
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
        if(nIns == 0) {
            revert BadArguments();
        }

        uint256 nOutsCopy = nOuts;
        uint8 noOfDigits = 0;

        while (nOutsCopy > 0) {
            noOfDigits++;
            nOutsCopy /= 10;
        }
        noOfDigits = noOfDigits == 0 ? 1 : noOfDigits;
        uint256 verifierID = nIns * 10 ** noOfDigits + nOuts;

        if (verifierID > type(uint16).max) {
            revert VerifierIdOverflow();
        }

        return uint16(verifierID);
    }
}
