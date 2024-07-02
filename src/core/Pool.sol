// SPDX-License-Identifie–: MIT
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
import {IScreener} from "../interfaces/IScreener.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {ZTransaction, ZTransactionLogic, RevokerData} from "../libraries/ZTransaction.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTree.sol";
import {REGISTER_ADDRESS_MESSASGE_PREFIX} from "../base/Constants.sol";

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

    /// @notice Initializes the Pool contract with the given parameters.
    /// @dev Pool is an UUPSUpgradeable contract, so it needs to be initialized.
    /// @param addressTreeDepth The depth of the address tree.
    /// @param commitmentTreeDepth The depth of the commitment tree.
    /// @param verifier_ The address of the verifier contract. Verifier contract verifies the ZTx's zk proof.
    /// @param adaptorHandler_ The address of the adaptor handler contract, responsible for delegate calling adaptors of external DeFi protocols.
    /// @param screener_ The address of the screener contract, responsible for screening sanctioned addresseses.
    /// @param hasher_ The address of the hasher contract. It provides a single interface to Poseidon hashing functions
    /// @param withdrawFeeBps_ The fee in basis points (1/10000) that is charged for withdrawing assets from the pool.
    function initialize(
        uint8 addressTreeDepth,
        uint8 commitmentTreeDepth,
        address verifier_,
        address adaptorHandler_,
        address screener_,
        address hasher_,
        uint256 withdrawFeeBps_
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        verifier = verifier_;
        adaptorHandler = adaptorHandler_;
        hasher = hasher_;
        screener = screener_;
        withdrawFeeBps = withdrawFeeBps_;

        _addressTree.init(addressTreeDepth, hasher_);
        _commitmentTree.init(commitmentTreeDepth, hasher_);
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
        address owner = msg.sender;
        uint256 withdrawFeeCollected = _withdrawFees[assetId];
        if (withdrawFeeCollected == 0) {
            revert NoFeeToClaim(owner, assetId);
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
        screener = screener_;
    }

    function setWithdrawFeeBips(uint256 feeBps) external onlyOwner {
        withdrawFeeBps = feeBps;
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        bytes calldata shieldedAddress,
        bytes calldata signature
    ) external whenNotPaused {
        uint256 rootAddress = uint256(bytes32(shieldedAddress));

        if (_rootAddresses[rootAddress]) {
            revert RootAddrAlreadyRegistered(rootAddress);
        }

        // Since shielded address = rootAddress (32-byte) + sign public key (32-byte) +
        // view public key (32-byte)
        if (shieldedAddress.length != 96) {
            revert BadArguments();
        }

        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
            bytes.concat(REGISTER_ADDRESS_MESSASGE_PREFIX, shieldedAddress)
        );

        address sender = ECDSA.recover(msgHash, signature);

        if (_publicAddresses[sender] > 0) {
            revert PublicAddrAlreadyRegistered(sender);
        }

        uint256 nextIndex = _addressTree.insert(rootAddress);
        _rootAddresses[rootAddress] = true;
        _publicAddresses[sender] = rootAddress;

        emit RegisterAddress(
            sender,
            rootAddress,
            nextIndex - 1,
            shieldedAddress
        );
    }

    function transact(
        ZTransaction calldata ztx
    ) external nonReentrant whenNotPaused {
        ztx.validate({
            addressTree: _addressTree,
            commitmentTree: _commitmentTree,
            markedNullifiers: _markedNullifiers,
            supportedAdaptors: _adaptors,
            revokerDataMap: _revokers,
            verifier: verifier
        });

        ztx.execute({
            commitmentTree: _commitmentTree,
            assets: _assets,
            withdrawFees: _withdrawFees,
            paymasterFees: _paymasterFees,
            adaptorHandler: adaptorHandler,
            hasher: hasher,
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
        ZTransaction calldata ztx
    ) external view returns (bool result) {
        RevokerData memory revokerData = _revokers[ztx.revokerId];

        result = ztx._verifyProof({
            revokerData: revokerData,
            verifier: verifier
        });
    }

    function getRevokerData(
        uint256 id
    ) external view returns (RevokerData memory) {
        return _revokers[id];
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

    function isMarkedNullifier(uint256 nullifier) external view returns (bool) {
        if (_markedNullifiers[nullifier] > 0) {
            return true;
        } else {
            return false;
        }
    }

    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory) {
        bool[] memory markedArr = new bool[](nullifiers.length);
        for (uint256 i = 0; i < nullifiers.length; ) {
            markedArr[i] = _markedNullifiers[nullifiers[i]] > 0 ? true : false;
            unchecked {
                ++i;
            }
        }
        return markedArr;
    }

    function zeroes(uint8 level) external view returns (uint256) {
        return _commitmentTree.zeroes[level];
    }

    function getCommitmentTreeDepth() external view returns (uint8) {
        return _commitmentTree.depth;
    }

    function getAddressTreeDepth() external view returns (uint8) {
        return _addressTree.depth;
    }

    function getCommitmentTreeNextLeafIndex() external view returns (uint32) {
        return _commitmentTree.nextLeafIndex;
    }

    function getAddressTreeNextLeafIndex() external view returns (uint32) {
        return _addressTree.nextLeafIndex;
    }

    function getCommitmentTreeLastRoot() external view returns (uint256) {
        return _commitmentTree.roots[_commitmentTree.currentRootIndex];
    }

    function getAddressTreeLastRoot() external view returns (uint256) {
        return _addressTree.roots[_addressTree.currentRootIndex];
    }

    function getCommitmentTreeCurrentRootIndex()
        external
        view
        returns (uint256)
    {
        return _commitmentTree.currentRootIndex;
    }

    function getAddressTreeCurrentRootIndex() external view returns (uint256) {
        return _addressTree.currentRootIndex;
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
