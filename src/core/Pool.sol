// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EIP712} from "../libraries/EIP712.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IScreener} from "../interfaces/IScreener.sol";
import {EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION} from "../base/Constants.sol";
import {PoolStorage, ProtocolFee} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTree.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "../libraries/QueuedMerkleTree.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "../libraries/ShieldedAddress.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType, RevokerData} from "../libraries/ShieldedTransaction.sol";

/// @param verifier The address of the verifier contract. Verifier contract verifies the stx's zk proof, address proof and merkle tree queue proof.
/// @param adaptorHandler The address of the adaptor handler contract, responsible for delegate calling adaptors of external DeFi protocols.
/// @param screener The address of the screener contract, responsible for screening sanctioned addresseses.
/// @param hasher The address of the hasher contract. It provides a single interface to Poseidon hashing functions
/// @param withdrawFeeBps The fee in basis points (1/10000) that is charged for withdrawing assets from the pool.
struct InitAddressParams {
    address mempool;
    address verifier;
    address adaptorHandler;
    address screener;
    address hasher;
    address verificationTrackerService;
}

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

    function initialize(
        uint8 addressTreeDepth,
        uint8 commitmentTreeDepth,
        uint8 commitmentTreeQueueSize,
        InitAddressParams calldata initAddressParams,
        uint256 withdrawFeeBps_
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        EIP712.init(EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION);

        mempool = initAddressParams.mempool;
        verifier = initAddressParams.verifier;
        adaptorHandler = initAddressParams.adaptorHandler;
        hasher = initAddressParams.hasher;
        screener = initAddressParams.screener;
        verificationTrackerService = initAddressParams
            .verificationTrackerService;
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

    function withdrawCollectedProtocolFee(
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
        screener = screener_;
    }

    function setDepositProtocolFee(
        uint16 feeBps,
        bool isActive
    ) external onlyOwner {
        depositProtocolFee = ProtocolFee({bps: feeBps, isActive: isActive});
    }

    function setWithdrawProtocolFee(
        uint16 feeBps,
        bool isActive
    ) external onlyOwner {
        withdrawProtocolFee = ProtocolFee({bps: feeBps, isActive: isActive});
    }

    function setTransferProtocolFee(
        uint16 feeBps,
        bool isActive
    ) external onlyOwner {
        transferProtocolFee = ProtocolFee({bps: feeBps, isActive: isActive});
    }

    function setAdaptorProtocolFee(
        uint16 feeBps,
        bool isActive
    ) external onlyOwner {
        adaptorProtocolFee = ProtocolFee({bps: feeBps, isActive: isActive});
    }

    function updateVerificationTrackerService(
        address verificationTrackerService_
    ) external onlyOwner {
        verificationTrackerService = verificationTrackerService_;
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        ShieldedAddressRegistrationData calldata addressRegData
    ) external whenNotPaused {
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
    }

    function updateCommitmentTree(
        TreeUpdateData calldata treeUpdateData
    ) external {
        _commitmentTree.update(treeUpdateData);
    }

    function transact(
        ShieldedTransaction calldata stx,
        bool isPreVerified
    ) public nonReentrant whenNotPaused {
        // constraining preVerified request sender to just the mempool contract.
        if (isPreVerified) {
            if (msg.sender != mempool) {
                revert IPool.InvalidSenderForPreverifiedSTX(
                    msg.sender,
                    mempool
                );
            }
        }

        uint16 protocolFeeBps = _getProtocolFeeBps(stx.txType);

        bytes32 packedValidationParams = _packValidationParams(
            isPreVerified,
            verifier,
            protocolFeeBps
        );

        stx.validate({
            addressTree: _addressTree,
            commitmentTree: _commitmentTree,
            markedNullifiers: _markedNullifiers,
            supportedAdaptors: _adaptors,
            revokerDataMap: _revokers,
            packedValidationParams: packedValidationParams
        });

        stx.execute({
            isPreVerified: isPreVerified,
            commitmentTree: _commitmentTree,
            assets: _assets,
            paymasterFees: _paymasterFees,
            proofSubAndExitMempoolFees: _proofSubAndMempoolExitFee,
            withdrawFees: _withdrawFees,
            hasher: hasher,
            adaptorHandler: adaptorHandler,
            protocolFeeBps: protocolFeeBps
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

    function withdrawExitMempoolFee(
        uint24 assetId
    ) external nonReentrant whenNotPaused {
        uint256 fee = _proofSubAndMempoolExitFee[assetId];
        if (fee == 0) {
            revert NoFeeToClaim(verificationTrackerService, assetId);
        }

        _proofSubAndMempoolExitFee[assetId] = 0;
        AssetLogic.transferAsset({
            assets: _assets,
            to: verificationTrackerService,
            assetId: assetId,
            value: fee
        });
    }

    /////////////////////////////////////////
    //         READ METHODS                //
    ////////////////////////////////////////

    /**
    function verifyTransactionProof(
        ShieldedTransaction calldata stx
    ) external view returns (bool result) {
        RevokerData memory revokerData = _revokers[stx.revokerId];

        result = stx.verifyProof({
            revokerData: revokerData,
            hasher: hasher,
            verifier: verifier
        });
    }
     */

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

    function getProtocolFee(
        ShieldedTransactionType txType
    ) external view returns (uint16) {
        return _getProtocolFeeBps(txType);
    }

    function getCollectedPaymasterFee(
        uint24 assertId,
        address paymaster
    ) external view returns (uint256) {
        return _paymasterFees[paymaster][assertId];
    }

    function getCollectedExitMempoolFee(
        uint24 assetId
    ) external view returns (uint256) {
        return _proofSubAndMempoolExitFee[assetId];
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

    /// @todo commenting out the treeRoot func. for now to keep the contract within deployable size.
    /**
    function isKnownCommitmentTreeRoot(
        uint256 root
    ) external view returns (bool) {
        return _commitmentTree.isKnownRoot(root);
    }

    function isKnownAddressTreeRoot(uint256 root) external view returns (bool) {
        return _addressTree.isKnownRoot(root);
    }
     */

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _packValidationParams(
        bool isPreVerified,
        address verifier,
        uint16 protocolFeeBps
    ) internal pure returns (bytes32) {
        return
            bytes32(
                (uint256(uint160(verifier)) << 96) |
                    (uint256(protocolFeeBps) << 80) |
                    (isPreVerified ? 1 : 0)
            );
    }

    function _getProtocolFeeBps(
        ShieldedTransactionType txType
    ) internal view returns (uint16 protocolFeeBps) {
        if (txType == ShieldedTransactionType.DEPOSIT) {
            protocolFeeBps = depositProtocolFee.isActive
                ? depositProtocolFee.bps
                : 0;
        } else if (txType == ShieldedTransactionType.WITHDRAW) {
            protocolFeeBps = withdrawProtocolFee.isActive
                ? withdrawProtocolFee.bps
                : 0;
        } else if (txType == ShieldedTransactionType.TRANSFER) {
            protocolFeeBps = transferProtocolFee.isActive
                ? transferProtocolFee.bps
                : 0;
        } else if (txType == ShieldedTransactionType.CALL_ADAPTOR) {
            protocolFeeBps = adaptorProtocolFee.isActive
                ? adaptorProtocolFee.bps
                : 0;
        } else {
            revert InvalidTransactionType();
        }
    }
}
