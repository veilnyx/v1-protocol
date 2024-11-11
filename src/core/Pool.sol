// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {EIP712} from "../libraries/EIP712.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IScreener} from "../interfaces/IScreener.sol";
import {EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION} from "../base/Constants.sol";
import {PoolStorage, ExternalContractAddresses} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTree.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "../libraries/QueuedMerkleTree.sol";
import {ShieldedAddressRegistrationData} from "../libraries/ShieldedAddress.sol";
import {AddressRegistry} from "./AddressRegistry.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, RevokerData} from "../libraries/ShieldedTransaction.sol";

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
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    // using ShieldedAddressLogic for ShieldedAddressRegistrationData;
    using ShieldedTransactionLogic for ShieldedTransaction;

    /// @notice Initializes the Pool contract with the given parameters.
    /// @dev Pool is an UUPSUpgradeable contract, so it needs to be initialized.
    /// @param addressTreeDepth The depth of the address tree.
    /// @param commitmentTreeDepth The depth of the commitment tree.
    /// @param withdrawFeeBps_ The fee in basis points (1/10000) that is charged for withdrawing assets from the pool.
    function initialize(
        uint8 addressTreeDepth,
        uint8 commitmentTreeDepth,
        uint8 commitmentTreeQueueSize,
        uint256 withdrawFeeBps_,
        ExternalContractAddresses calldata externalContracts_
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        EIP712.init(EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION);

        externalContracts.verifier = externalContracts_.verifier;
        externalContracts.adaptorHandler = externalContracts_.adaptorHandler;
        externalContracts.hasher = externalContracts_.hasher;
        externalContracts.screener = externalContracts_.screener;
        externalContracts.addressRegistry = externalContracts_.addressRegistry;
        withdrawFeeBps = withdrawFeeBps_;

        _commitmentTree.init(
            commitmentTreeDepth,
            commitmentTreeQueueSize,
            externalContracts_.hasher,
            externalContracts_.verifier
        );
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
        address[] calldata assetAddresses
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
        externalContracts.screener = screener_;
    }

    function setWithdrawFeeBips(uint256 feeBps) external onlyOwner {
        withdrawFeeBps = feeBps;
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        ShieldedAddressRegistrationData calldata addressRegData
    ) external whenNotPaused returns (MessagingReceipt memory) {
        /**
        bytes32 hashStruct = ShieldedAddressLogic.hashRegsiterAddressStruct(
            addressRegData.shieldedAddress
        );
        bytes32 hashTypedData = EIP712.hashTypedDataV4(hashStruct);

        addressRegData.register({
            addressTree: _addressTree,
            publicAddresses: _publicAddresses,
            rootAddresses: _rootAddresses,
            verifier: verifier,
            hashTypedData: hashTypedData
        });
        */

        /// @todo: Pool should send the estimated value to the addressRegistry for syncing the tree state cross-chain.
        (
            uint256 updatedAddressTreeRoot,
            uint8 currentRootIndex,
            MessagingReceipt memory crossChainSyncReceipt
        ) = AddressRegistry(externalContracts.addressRegistry).register(addressRegData);

        _addressTree.currentRootIndex = currentRootIndex;
        _addressTree.roots[currentRootIndex] = updatedAddressTreeRoot;

        return crossChainSyncReceipt;
    }

    function setAddressTreeUpdator(
        address addressTreeUpdator
    ) external onlyOwner {
        externalContracts.addressTreeUpdator = addressTreeUpdator;
    }

    function updateAddressTree(
        uint256 updatedAddressTreeRoot,
        uint8 currentRootIndex
    ) external whenNotPaused {
        require(
            msg.sender == externalContracts.addressTreeUpdator,
            "Pool: Unauthorized"
        );
        _addressTree.currentRootIndex = currentRootIndex;
        _addressTree.roots[currentRootIndex] = updatedAddressTreeRoot;
    }

    function updateCommitmentTree(
        TreeUpdateData calldata treeUpdateData
    ) external {
        _commitmentTree.update(treeUpdateData);
    }

    function transact(
        ShieldedTransaction calldata stx
    ) external nonReentrant whenNotPaused {
        stx.validate({
            addressRegistry: externalContracts.addressRegistry,
            commitmentTree: _commitmentTree,
            markedNullifiers: _markedNullifiers,
            supportedAdaptors: _adaptors,
            revokerDataMap: _revokers,
            verifier: externalContracts.verifier
        });

        stx.execute({
            commitmentTree: _commitmentTree,
            assets: _assets,
            withdrawFees: _withdrawFees,
            paymasterFees: _paymasterFees,
            adaptorHandler: externalContracts.adaptorHandler,
            hasher: externalContracts.hasher,
            withdrawFeeBps: withdrawFeeBps
        });
    }

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

    function verifyTransactionProof(
        ShieldedTransaction calldata stx
    ) external view returns (bool result) {
        RevokerData memory revokerData = _revokers[stx.revokerId];

        result = stx._verifyProof({
            revokerData: revokerData,
            verifier: externalContracts.verifier
        });
    }

    function getRevokerData(
        uint256 id
    ) external view returns (RevokerData memory) {
        return _revokers[id];
    }

    function getAsset(uint24 assetId) external view returns (Asset memory) {
        return _assets[assetId];
    }

    /// @notice Returns the data of an asset.
    /// @param assetAddress The address of the asset.
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
        uint24 assertId,
        address paymaster
    ) external view returns (uint256) {
        return _paymasterFees[paymaster][assertId];
    }

    function isAdaptorSupported(
        address adaptorAddress
    ) external view returns (bool) {
        return _adaptors[adaptorAddress];
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

    function getAddressTreeState()
        external
        view
        returns (uint256 lastRoot, uint8 currentRootIndex)
    {
        return (
            _addressTree.roots[_addressTree.currentRootIndex],
            _addressTree.currentRootIndex
        );
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
