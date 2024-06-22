// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {ZTransaction, ZTransactionLogic, ComplianceKeys} from "../libraries/ZTransaction.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTree.sol";

contract Pool is
    IPool,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    PoolStorage
{
    using MerkleTreeLogic for MerkleTree;
    using ZTransactionLogic for ZTransaction;

    function initialize(
        uint256 addressTreeDepth,
        uint256 commitmentTreeDepth,
        address verifier_,
        address adaptorHandler_
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        verifier = verifier_;
        adaptorHandler = adaptorHandler_;

        _addressTree.init(addressTreeDepth);
        _commitmentTree.init(commitmentTreeDepth);
    }

    /////////////////////////////////////////
    //         ADMIN WRITE METHODS         //
    ////////////////////////////////////////

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addAssets(
        AssetType assetType,
        address[] memory assetAddresses
    ) external onlyOwner {
        _assetCounts[assetType] = AssetLogic.addAssets({
            assetIds: _assetIds,
            assets: _assets,
            counter: _assetCounts[assetType],
            assetType: assetType,
            assetAddresses: assetAddresses
        });
    }

    function addAdaptorSupport(
        address adaptorAddress,
        bool enable
    ) external onlyOwner {
        _adaptors[adaptorAddress] = enable;
    }

    function registerComplianceKeys(
        uint256[2] calldata revokerPublicKey,
        uint256[2] calldata encryptionPublicKey
    ) external onlyOwner {
        uint16 id = _complianceKeysCount;

        ComplianceKeys memory complianceKeys = ComplianceKeys({
            id: id,
            revokerPublicKey: revokerPublicKey,
            encryptionPublicKey: encryptionPublicKey,
            isActive: true
        });

        _complianceKeys[id] = complianceKeys;
        emit RegisterComplianceKeys(id, revokerPublicKey, encryptionPublicKey);

        _complianceKeysCount += 1;
    }

    function setComplianceKeysStatus(
        uint256 id,
        bool isActive
    ) external onlyOwner {
        _complianceKeys[id].isActive = isActive;
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        uint256 addr,
        bytes calldata publicKeys,
        bytes calldata signature
    ) external whenNotPaused {
        if (_addressRegistered[addr]) {
            revert AddressAlreadyRegistered(addr);
        }

        // Each public key is 32 bytes long
        if (publicKeys.length != 64) {
            revert BadArguments();
        }

        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
            bytes.concat(bytes32(addr), publicKeys)
        );

        address sender = ECDSA.recover(msgHash, signature);

        uint256 regIdx = _addressTree.insert(addr);
        _addressRegistered[addr] = true;

        emit RegisterAddress(sender, addr, regIdx, publicKeys);
    }

    function transact(
        ZTransaction memory ztx
    ) external nonReentrant whenNotPaused {
        ztx.execute({
            commitmentTree: _commitmentTree,
            addressTree: _addressTree,
            assets: _assets,
            adaptors: _adaptors,
            markedNullifiers: _markedNullifiers,
            complianceKeys: _complianceKeys,
            verifier: verifier,
            adaptorHandler: adaptorHandler
        });
    }

    /////////////////////////////////////////
    //         READ METHODS                //
    ////////////////////////////////////////

    function verifyTransactionProof(
        ZTransaction calldata ztx
    ) external view returns (bool) {
        ComplianceKeys memory cKeys = _complianceKeys[ztx.complianceKeysId];
        return IVerifier(verifier).verifyTransactionProof(ztx, cKeys);
    }

    function getComplianceKeys(
        uint256 id
    ) external view returns (ComplianceKeys memory) {
        return _complianceKeys[id];
    }

    function assetCount(AssetType assetType) external view returns (uint24) {
        return _assetCounts[assetType];
    }

    function isAssetSupported(
        address assetAddress
    ) external view returns (bool) {
        uint24 id = _assetIds[assetAddress];
        return _assets[id].isSupported;
    }

    function getAsset(uint24 assetId) external view returns (Asset memory) {
        return _assets[assetId];
    }

    function getAsset(
        address assetAddress
    ) external view returns (Asset memory) {
        uint24 id = _assetIds[assetAddress];
        return _assets[id];
    }

    function isAdaptorSupported(
        address adaptorAddress
    ) external view returns (bool) {
        return _adaptors[adaptorAddress];
    }

    function isMarkedNullifier(uint256 nullifier) external view returns (bool) {
        return _markedNullifiers[nullifier];
    }

    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory) {
        bool[] memory markedArr = new bool[](nullifiers.length);
        for (uint256 i = 0; i < nullifiers.length; ) {
            markedArr[i] = _markedNullifiers[nullifiers[i]];
            unchecked {
                ++i;
            }
        }
        return markedArr;
    }

    function zeroes(uint256 level) external view returns (uint256) {
        return _commitmentTree.zeroes[level];
    }

    function getCommitmentTreeDepth() external view returns (uint256) {
        return _commitmentTree.depth;
    }

    function getCommitmentTreeNextLeafIndex() external view returns (uint256) {
        return _commitmentTree.nextLeafIndex;
    }

    function getCommitmentTreeLastRoot() external view returns (uint256) {
        return _commitmentTree.roots[_commitmentTree.currentRootIndex];
    }

    function getCommitmentTreeCurrentRootIndex()
        external
        view
        returns (uint256)
    {
        return _commitmentTree.currentRootIndex;
    }

    function getAddressTreeDepth() external view returns (uint256) {
        return _addressTree.depth;
    }

    function isKnownRoot(uint256 root) external view returns (bool) {
        return _commitmentTree.isKnownRoot(root);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
