// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {VerifierRegister} from "../verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "../verifiers/VerifierTreeUpdate.sol";
import {MerkleTree} from "../libraries/MerkleTreeLogic.sol";

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

    /// @notice Address authorised to add, update and remove verifiers.
    address public verifierManager;

    event TransactionVerifierAdded(
        uint16 indexed id,
        bytes4 selector,
        address addr
    );
    event TransactionVerifierRemoved(uint16 indexed id);
    event TreeUpdateVerifierUpdated(address indexed newTreeUpdateVerifier);
    event AddressVerifierUpdated(address indexed newAddressVerifier);
    event VerifierManagerUpdated(
        address indexed previousManager,
        address indexed newManager
    );

    error ZeroAddress();
    error VerifierAlreadyExists(uint16 id);
    error NotVerifierManager();

    modifier onlyVerifierManager() {
        if (msg.sender != verifierManager) revert NotVerifierManager();
        _;
    }

    constructor(
        TransactionVerifierInfo[] memory txvInfos,
        address addressVerifier,
        address treeUpdateVerifier,
        address verifierManager_
    ) Ownable(msg.sender) {
        if (
            addressVerifier == address(0) ||
            treeUpdateVerifier == address(0) ||
            verifierManager_ == address(0)
        ) revert ZeroAddress();

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

        verifierManager = verifierManager_;
        emit VerifierManagerUpdated(address(0), verifierManager_);
    }

    /// @notice Transfers the verifier manager role to a new address.
    /// @dev Only callable by owner.
    /// @param newManager The address to assign as the new verifier manager.
    function setVerifierManager(address newManager) external onlyOwner {
        if (newManager == address(0)) revert ZeroAddress();
        emit VerifierManagerUpdated(verifierManager, newManager);
        verifierManager = newManager;
    }

    /// @notice Updates the tree update verifier
    /// @dev Only callable by verifier manager
    /// @param newTreeUpdateVerifier The new tree update verifier address
    function updateTreeUpdateVerifier(
        address newTreeUpdateVerifier
    ) external onlyVerifierManager {
        if (newTreeUpdateVerifier == address(0)) revert ZeroAddress();
        _treeUpdateVerifier = newTreeUpdateVerifier;
        emit TreeUpdateVerifierUpdated(_treeUpdateVerifier);
    }

    /// @notice Updates the address verifier
    /// @dev Only callable by verifier manager
    /// @param newAddressVerifier The new address verifier address
    function updateAddressVerifier(
        address newAddressVerifier
    ) external onlyVerifierManager {
        if (newAddressVerifier == address(0)) revert ZeroAddress();
        _addressVerifier = newAddressVerifier;
        emit AddressVerifierUpdated(_addressVerifier);
    }

    /// @notice Adds a new transaction verifier
    /// @dev Only callable by verifier manager
    /// @param txvInfo The transaction verifier info to add
    function addTransactionVerifier(
        TransactionVerifierInfo calldata txvInfo
    ) external onlyVerifierManager {
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
    /// @dev Only callable by verifier manager
    /// @param txvInfos Array of transaction verifier infos to add
    function addTransactionVerifiers(
        TransactionVerifierInfo[] calldata txvInfos
    ) external onlyVerifierManager {
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
    /// @dev Only callable by verifier manager
    /// @param vId The verifier ID to remove
    function removeTransactionVerifier(
        uint16 vId
    ) external onlyVerifierManager {
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
        if (nIns == 0) {
            revert BadArguments(nIns, nOuts);
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
            revert VerifierIdOverflow(verifierID);
        }

        return uint16(verifierID);
    }
}
