// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IAssetManager} from "../interfaces/IAssetManager.sol";
import {IConvertor} from "../interfaces/IConvertor.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {PoolAccount} from "../base/PoolAccount.sol";
import {PoolLogic} from "../libraries/PoolLogic.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTreeLogic.sol";
import {ZTransaction} from "../libraries/ZTransaction.sol";
import {Asset, AssetType} from "../libraries/DataTypes.sol";

contract Pool is
    IAssetManager,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PoolStorage,
    PoolAccount
{
    using MerkleTreeLogic for MerkleTree;

    constructor(address entryPoint_) PoolAccount(entryPoint_) {}

    function initialize(
        uint256 treeDepth,
        address verifier_,
        address convertor_,
        AssetType[] calldata initAssetTypes,
        address[] calldata initAssetAddresses
    ) external initializer {
        convertor = convertor_;
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        verifier = verifier_;
        convertor = convertor_;

        _tree.init(treeDepth);
        _counter = PoolLogic.addAssets(
            _assetIds,
            _assets,
            0,
            initAssetTypes,
            initAssetAddresses
        );
    }

    function transact(ZTransaction memory ztx) external payable nonReentrant {
        PoolLogic.executeTransaction({
            tree: _tree,
            assets: _assets,
            supportedProxies: _supportedProxies,
            markedNullifiers: _markedNullifiers,
            verifier: verifier,
            convertor: convertor,
            ztx: ztx
        });
    }

    function verifyTransactionProof(
        ZTransaction calldata ztx
    ) external view returns (bool) {
        return IVerifier(verifier).verifyTransactionProof(ztx);
    }

    function setProxy(address proxyAddress, bool enable) external onlyOwner {
        _supportedProxies[proxyAddress] = enable;
    }

    function addAssets(
        AssetType[] calldata assetTypes,
        address[] calldata assetAddresses
    ) external onlyOwner {
        _counter = PoolLogic.addAssets({
            assetIds: _assetIds,
            assets: _assets,
            counter: _counter,
            assetTypes: assetTypes,
            assetAddresses: assetAddresses
        });
    }

    function assetCount() public view returns (uint24) {
        return _counter;
    }

    function isProxySupported(address proxyAddress) public view returns (bool) {
        return _supportedProxies[proxyAddress];
    }

    function isAssetSupported(uint24 assetId) public view returns (bool) {
        return getAsset(assetId).isSupported;
    }

    function isAssetSupported(address assetAddress) public view returns (bool) {
        return getAsset(assetAddress).isSupported;
    }

    function getAsset(uint24 assetId) public view returns (Asset memory) {
        return _assets[assetId];
    }

    function getAsset(address assetAddress) public view returns (Asset memory) {
        return _assets[_assetIds[assetAddress]];
    }

    function getAssetId(address assetAddress) public view returns (uint24) {
        return _assetIds[assetAddress];
    }

    function isMarkedNullifier(uint256 nullifier) public view returns (bool) {
        return _markedNullifiers[nullifier];
    }

    function zeroes(uint256 level) public view returns (uint256) {
        return _tree.zeroes[level];
    }

    function getLastRoot() public view returns (uint256) {
        return _tree.roots[_tree.currentRootIndex];
    }

    function getCurrentRootIndex() public view returns (uint256) {
        return _tree.currentRootIndex;
    }

    function getLastSubtrees(uint256 level) public view returns (uint256) {
        return _tree.lastSubtrees[level];
    }

    function isKnownRoot(uint256 root) public view returns (bool) {
        return _tree.isKnownRoot(root, ROOT_HISTORY_SIZE);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _authorizeAssetUpdate() internal onlyOwner {}

    function _authorizeWithdrawAccountDeposit() internal override onlyOwner {}

    receive() external payable {}
}
