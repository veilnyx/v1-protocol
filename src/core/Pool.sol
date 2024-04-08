// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IConvertor} from "../interfaces/IConvertor.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {PoolAccount} from "../base/PoolAccount.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {ZTransaction, ZTransactionLogic} from "../libraries/ZTransaction.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTree.sol";

contract Pool is
    IPool,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PoolStorage,
    PoolAccount
{
    using MerkleTreeLogic for MerkleTree;
    using ZTransactionLogic for ZTransaction;

    function initialize(
        uint256 treeDepth,
        address verifier_,
        address convertor_,
        address entryPoint_,
        AssetType initAssetType,
        address[] calldata initAssetAddresses
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        verifier = verifier_;
        convertor = convertor_;
        entryPoint = entryPoint_;

        _tree.init(treeDepth);
        _assetCounts[initAssetType] = AssetLogic.addAssets(
            _assetIds,
            _assets,
            0,
            initAssetType,
            initAssetAddresses
        );
    }

    function transact(ZTransaction memory ztx) external nonReentrant {
        ztx.execute({
            tree: _tree,
            assets: _assets,
            convertProxies: _convertProxies,
            markedNullifiers: _markedNullifiers,
            verifier: verifier,
            convertor: convertor
        });
    }

    function addAssets(
        AssetType assetType,
        address[] memory assetAddresses
    ) external {
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
    ) public view returns (bool) {
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
        return _tree.zeroes[level];
    }

    function getLastRoot() external view returns (uint256) {
        return _tree.roots[_tree.currentRootIndex];
    }

    function getCurrentRootIndex() external view returns (uint256) {
        return _tree.currentRootIndex;
    }

    function getLastSubtrees(uint256 level) external view returns (uint256) {
        return _tree.lastSubtrees[level];
    }

    function isKnownRoot(uint256 root) external view returns (bool) {
        return _tree.isKnownRoot(root, ROOT_HISTORY_SIZE);
    }

    function getRevokerPublicKey() external view returns (uint256, uint256) {
        return IVerifier(verifier).getRevokerPublicKey();
    }

    function getEncryptionPublicKey() external view returns (uint256, uint256) {
        return IVerifier(verifier).getEncryptionPublicKey();
    }

    function _entryPoint() internal view override returns (address) {
        return entryPoint;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _authorizeAssetUpdate() internal onlyOwner {}

    function _authorizeWithdrawAccountDeposit() internal override onlyOwner {}
}
