// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool, InitAddressParams} from "../interfaces/IPool.sol";
import {IScreener} from "../interfaces/IScreener.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IScreener} from "../interfaces/IScreener.sol";
import {EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, MAX_WITHDRAW_FEE_BPS} from "../base/Constants.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTree.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "../libraries/QueuedMerkleTree.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "../libraries/ShieldedAddress.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, RevokerData} from "../libraries/ShieldedTransaction.sol";

contract Pool is
    IPool,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    PoolStorage
{
    using MerkleTreeLogic for MerkleTree;
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    using ShieldedAddressLogic for ShieldedAddressRegistrationData;
    using ShieldedTransactionLogic for ShieldedTransaction;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the Pool contract with the given parameters.
    /// @dev Pool is an UUPSUpgradeable contract, so it needs to be initialized.
    /// @param addressTreeDepth The depth of the address tree.
    /// @param commitmentTreeDepth The depth of the commitment tree.
    /// @param commitmentTreeQueueSize The size of the queue for the commitment tree. This determines how many leaves can be queued at MAX before a tree update is required. Defined by the circuit `treeUpdate::nLeaves`
    function initialize(
        uint8 addressTreeDepth,
        uint8 commitmentTreeDepth,
        uint8 commitmentTreeQueueSize,
        InitAddressParams calldata initAddressParams,
        uint256 withdrawFeeBps_
    ) external initializer {
        if (withdrawFeeBps_ > MAX_WITHDRAW_FEE_BPS) {
            revert IPool.WithdrawalFeeTooHigh(
                withdrawFeeBps_,
                MAX_WITHDRAW_FEE_BPS
            );
        }

        __Ownable_init_unchained(msg.sender);
        __UUPSUpgradeable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();
        EIP712Upgradeable.__EIP712_init_unchained(
            EIP712_DOMAIN_NAME,
            EIP712_DOMAIN_VERSION
        );

        verifier = initAddressParams.verifier;
        adaptorHandler = initAddressParams.adaptorHandler;
        hasher = initAddressParams.hasher;
        screener = initAddressParams.screener;

        withdrawFeeBps = withdrawFeeBps_;

        _addressTree.init(addressTreeDepth, hasher);
        _commitmentTree.init(
            commitmentTreeDepth,
            commitmentTreeQueueSize,
            hasher,
            verifier
        );
    }

    /////////////////////////////////////////
    //         ADMIN WRITE METHODS         //
    ////////////////////////////////////////
    /// @custom:invariant ACCESS-1 Owner can upgrade, pause, add assets/adaptors, register revokers
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addAssets(
        AssetType assetType,
        address[] calldata assetAddresses
    ) external onlyOwner {
        _assetCounts[assetType] = AssetLogic.addAssets({
            assetIds: _assetIds,
            assets: _assets,
            assetCount: _assetCounts[assetType],
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

    function registerRevoker(
        uint256[2] calldata revokerPublicKey,
        uint256[2] calldata encryptionPublicKey,
        bytes calldata revokerMetadata
    ) external onlyOwner {
        uint16 id = _revokerCount;
        uint256 revokerPublicKeyHash = uint256(
            keccak256((abi.encode(revokerPublicKey)))
        );

        if (_revokerPublicKeys[revokerPublicKeyHash]) {
            revert DuplicateRevoker(revokerPublicKey);
        }

        _revokerPublicKeys[revokerPublicKeyHash] = true;

        RevokerData memory revokerData = RevokerData({
            id: id,
            isActive: true,
            revokerPublicKey: revokerPublicKey,
            encryptionPublicKey: encryptionPublicKey
        });

        _revokers[id] = revokerData;
        emit RevokerRegistered(
            id,
            revokerPublicKey,
            encryptionPublicKey,
            revokerMetadata
        );

        _revokerCount += 1;
    }

    function withdrawProtocolFee(
        uint24 assetId,
        address to
    ) external nonReentrant onlyOwner {
        uint256 withdrawFeeCollected = _withdrawFees[assetId];
        if (withdrawFeeCollected == 0) {
            revert NoFeeToClaim(msg.sender, assetId);
        }

        _withdrawFees[assetId] = 0;
        AssetLogic.transferAsset({
            assets: _assets,
            to: to,
            assetId: assetId,
            value: withdrawFeeCollected
        });
    }

    function setRevokerStatus(uint256 id, bool isActive) external onlyOwner {
        _revokers[id].isActive = isActive;
        emit IPool.RevokerStatusUpdated(id, isActive);
    }

    function setScreener(address screener_) external onlyOwner {
        screener = IScreener(screener_);
        emit ScreenerUpdated(screener_);
    }

    /// @custom:invariant FEE-1: withdrawFeeBps cannot be set above MAX_WITHDRAW_FEE_BPS
    function setWithdrawFeeBips(uint256 feeBps) external onlyOwner {
        if (feeBps > MAX_WITHDRAW_FEE_BPS) {
            revert IPool.WithdrawalFeeTooHigh(feeBps, MAX_WITHDRAW_FEE_BPS);
        }
        withdrawFeeBps = feeBps;
        emit WithdrawFeeUpdated(feeBps);
    }

    /// @notice Sets the protocol version number.
    /// @dev This is used to track the pool contract version since EIP-712 domain
    ///      name and version MUST NOT be changed (see README for critical warnings).
    /// @param version_ The new version number to set.
    function setVersion(uint64 version_) external onlyOwner {
        version = version_;
        emit IPool.VersionUpdated(version_);
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        ShieldedAddressRegistrationData calldata addressRegData
    ) external whenNotPaused {
        bytes32 hashTypedData = _hashTypedDataV4(
            ShieldedAddressLogic.hashRegsiterAddressStruct(
                addressRegData.shieldedAddress
            )
        );

        addressRegData.register({
            addressTree: _addressTree,
            publicAddresses: _publicAddresses,
            rootAddresses: _rootAddresses,
            verifier: verifier,
            hashTypedData: hashTypedData
        });
    }

    function updateCommitmentTree(
        TreeUpdateData calldata treeUpdateData
    ) external whenNotPaused {
        _commitmentTree.update(treeUpdateData);
    }

    function transact(
        ShieldedTransaction calldata stx
    ) public nonReentrant whenNotPaused {
        stx.validate({
            addressTree: _addressTree,
            commitmentTree: _commitmentTree,
            verifier: address(verifier),
            markedNullifiers: _markedNullifiers,
            supportedAdaptors: _adaptors,
            revokerDataMap: _revokers
        });

        stx.execute({
            commitmentTree: _commitmentTree,
            assets: _assets,
            paymasterFees: _paymasterFees,
            withdrawFees: _withdrawFees,
            hasher: address(hasher),
            adaptorHandler: address(adaptorHandler),
            withdrawFeeBps: withdrawFeeBps
        });
    }

    /// @custom:invariant ACCESS-3: Only paymasters can withdraw their accumulated fees
    function withdrawPaymasterFee(
        uint24 assetId,
        address to
    ) external nonReentrant whenNotPaused {
        address paymaster = msg.sender;
        uint256 fee = _paymasterFees[paymaster][assetId];
        if (fee == 0) {
            revert NoFeeToClaim(paymaster, assetId);
        }

        _paymasterFees[paymaster][assetId] = 0;
        AssetLogic.transferAsset({
            assets: _assets,
            to: to,
            assetId: assetId,
            value: fee
        });
    }

    /////////////////////////////////////////
    //         READ METHODS                //
    ////////////////////////////////////////
    function getRevokerData(
        uint256 id
    ) external view returns (RevokerData memory) {
        return _revokers[id];
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

    function getCollectedWithdrawFee(
        uint24 assetId
    ) external view returns (uint256) {
        return _withdrawFees[assetId];
    }

    function getCollectedPaymasterFee(
        uint24 assetId,
        address paymaster
    ) external view returns (uint256) {
        return _paymasterFees[paymaster][assetId];
    }

    function isAdaptorSupported(
        address adaptorAddress
    ) external view returns (bool) {
        return _adaptors[adaptorAddress];
    }

    function getCommitmentTreeState()
        external
        view
        returns (
            uint256[] memory queuedLeaves,
            uint256[] memory lastSubtrees,
            uint256 lastRoot,
            uint8 currentRootIndex,
            uint32 nextLeafIndex
        )
    {
        (
            queuedLeaves,
            lastSubtrees,
            lastRoot,
            currentRootIndex,
            nextLeafIndex
        ) = _commitmentTree.getState();
    }

    function getAddressTreeState()
        external
        view
        returns (
            uint256[] memory lastSubtrees,
            uint256 lastRoot,
            uint8 currentRootIndex,
            uint32 nextLeafIndex
        )
    {
        (lastSubtrees, lastRoot, currentRootIndex, nextLeafIndex) = _addressTree
            .getState();
    }

    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory) {
        bool[] memory markedArr = new bool[](nullifiers.length);
        uint256 nullifiersLen = nullifiers.length;

        for (uint256 i = 0; i < nullifiersLen; ) {
            markedArr[i] = _markedNullifiers[nullifiers[i]] != 0;

            unchecked {
                ++i;
            }
        }

        return markedArr;
    }

    function isKnownCommitmentTreeRoot(
        uint256 root
    ) external view returns (bool) {
        return _commitmentTree.isKnownRoot(root);
    }

    function isKnownAddressTreeRoot(uint256 root) external view returns (bool) {
        return _addressTree.isKnownRoot(root);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
