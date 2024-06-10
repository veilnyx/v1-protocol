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
import {IConvertor} from "../interfaces/IConvertor.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {ZTransaction, ZTransactionLogic} from "../libraries/ZTransaction.sol";
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
        uint256 treeDepth,
        address verifier_,
        address convertor_,
        AssetType initAssetType,
        address[] calldata initAssetAddresses
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        verifier = verifier_;
        convertor = convertor_;

        _commitmentTree.init(treeDepth);
        _assetCounts[initAssetType] = AssetLogic.addAssets(
            _assetIds,
            _assets,
            0,
            initAssetType,
            initAssetAddresses
        );
    }

    function transact(
        ZTransaction memory ztx
    ) external nonReentrant whenNotPaused {
        ztx.execute({
            tree: _commitmentTree,
            assets: _assets,
            convertProxies: _convertProxies,
            markedNullifiers: _markedNullifiers,
            verifier: verifier,
            convertor: convertor
        });
    }

    function registerComplianceKeys(
        uint256[4] calldata keys
    ) external onlyOwner {
        complianceKeys[_complianceKeysCount] = keys;
        emit RegisterComplianceKeys(_complianceKeysCount, keys);
        _complianceKeysCount += 1;
    }

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

    function setConvertProxy(
        address proxyAddress,
        bool enable
    ) external onlyOwner {
        _convertProxies[proxyAddress] = enable;
    }

    function verifyTransactionProof(
        ZTransaction calldata ztx
    ) external view returns (bool) {
        return IVerifier(verifier).verifyTransactionProof(ztx);
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

    function isConvertProxySupported(
        address proxyAddress
    ) external view returns (bool) {
        return _convertProxies[proxyAddress];
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

    function getLastRoot() external view returns (uint256) {
        return _commitmentTree.roots[_commitmentTree.currentRootIndex];
    }

    function getCurrentRootIndex() external view returns (uint256) {
        return _commitmentTree.currentRootIndex;
    }

    function getLastSubtrees(uint256 level) external view returns (uint256) {
        return _commitmentTree.lastSubtrees[level];
    }

    function isKnownRoot(uint256 root) external view returns (bool) {
        return _commitmentTree.isKnownRoot(root);
    }

    function getRevokerPublicKey() external view returns (uint256, uint256) {
        return IVerifier(verifier).getRevokerPublicKey();
    }

    function getEncryptionPublicKey() external view returns (uint256, uint256) {
        return IVerifier(verifier).getEncryptionPublicKey();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
