// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IMempool, PreVerificationDetails} from "src/interfaces/IMempool.sol";
import {MempoolStorage} from "src/base/MempoolStorage.sol";
import {MempoolValidator} from "src/libraries/MempoolValidator.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType, PubAsset} from "src/libraries/ShieldedTransaction.sol";
import {Asset, AssetLogic, AssetType} from "src/libraries/Asset.sol";
import {INebraUpa} from "../interfaces/INebraUpa.sol";

/// @dev Prerequisite 1: Mempool::updatePool(..) needs to be called immediately after the Mempool deployment, if Pool address is 0x. This will not be the case when pool is getting updated as pool proxy address will be preknown.
/// @dev Prerequisite 2: Mempool::updateGatewayContract(..) needs to be called immediately after the Mempool deployment, since Gateway address is not known at the time of Mempool deployment.
contract Mempool is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuard,
    IMempool,
    MempoolStorage
{
    using MempoolValidator for ShieldedTransaction;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    function initialize(
        address pool_,
        uint256 mempoolExitFee_,
        address verificationTrackerService_,
        address nebraVerifier_,
        address gateway_
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        pool = IPool(pool_);
        mempoolExitFee = mempoolExitFee_;
        verificationTrackerService = verificationTrackerService_;
        nebraVerifier = nebraVerifier_;
        gateway = gateway_;
    }

    ///////////////////////////
    //// External Functions ///
    ///////////////////////////

    /// @notice Add a shielded transaction to the mempool
    /// @notice Only Deposit tx are allowed to be received from public wallets. Non-Deposit tx should only come through the ERC4337 infra to protect privacy and manage fees reimbursements to Paymaster and verification tracker service directly from the Laby pool.
    /// @notice For Deposit tx, the mempool exit fee will be received from the user, for reimbursing the verification tracker service.
    function addSTXToMempool(
        ShieldedTransaction calldata stx,
        PreVerificationDetails calldata preVerificationDetails
    ) external payable whenNotPaused {
        address stxSender = msg.sender;
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];

        stx.validityChecksBeforeAddingSTXToMempool(
            stxHashPI,
            pool,
            _stxHashes,
            gateway,
            mempoolExitFee,
            depositBalance
        );

        bytes32 proofId = keccak256(
            abi.encodePacked(
                preVerificationDetails.circuitId,
                preVerificationDetails.publicInputs
            )
        );

        stxToProofId[stxHashPI] = proofId;
        stxMap[stxHashPI] = stx;
        stxSenders[stxHashPI] = stxSender;
        _stxHashes.add(stxHashPI);
        mempoolExitFeeCollected += mempoolExitFee;

        emit STXAddedToMempool(stxHashPI, stxSender, proofId, block.timestamp);
        emit LockNotes(stxHashPI, stx.nullifiers);
    }

    /// @notice Take STX out of the mempool and execute it
    function exitSTXFromMempool(uint256 stxHash) external {
        if (!_stxHashes.contains(stxHash)) {
            revert STXNotInMempool(stxHash);
        }

        ShieldedTransaction memory stx = stxMap[stxHash];
        bytes32 proofId = stxToProofId[stxHash];

        // Onchain check with Nebra to ensure the proof is verified
        bool isProofValid = INebraUpa(nebraVerifier).isProofVerified(proofId);
        if (!isProofValid) {
            revert STXNotPreVerified(stxHash, proofId);
        }

        // Approve assets to the pool only for DEPOSIT tx
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            for (uint i = 0; i < stx.pubAssets.length; i++) {
                (uint24 assetId, uint224 value) = MempoolValidator.decodeAsset(
                    stx.pubAssets[i]
                );
                Asset memory asset = MempoolValidator.checkIfAssetValid(
                    assetId,
                    pool
                );

                IERC20(asset.assetAddress).forceApprove(address(pool), value);
                // Update the deposit balance of the stx sender
                depositBalance[stxSenders[stxHash]][assetId] -= value;
            }
        }

        // Remove STX from mempool
        _stxHashes.remove(stxHash);
        delete stxMap[stxHash];
        delete stxToProofId[stxHash];
        delete stxSenders[stxHash];

        // Transact the STX
        pool.transact(stx, true);
        emit STXProcessed(stxHash, proofId, block.timestamp);
        emit UnlockNotes(stxHash, stx.nullifiers);
    }

    /**
    /// @notice Drops the STX from mempool if it's proof is not verified yet or has failed verification.
    /// @notice Refunds the user their deposit assets.
    function dropFromMempool(uint256 stxHash) external nonReentrant {
        if (!_stxHashes.contains(stxHash)) {
            revert STXNotInMempool(stxHash);
        }

        ShieldedTransaction memory stx = stxMap[stxHash];
        address stxSender = stxSenders[stxHash];
        bytes32 proofId = stxToProofId[stxHash];

        // if proof is verified, don't allow refunds
        bool isProofValid = INebraUpa(nebraVerifier).isProofVerified(proofId);
        if (isProofValid) {
            revert STXNonRefundable(stxHash);
        }

        // refund deposited assets to the stx sender only for DEPOSIT tx
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            for (uint i = 0; i < stx.pubAssets.length; i++) {
                (uint24 assetId, uint224 value) = MempoolValidator.decodeAsset(
                    stx.pubAssets[i]
                );
                Asset memory asset = MempoolValidator.checkIfAssetValid(
                    assetId,
                    pool
                );

                IERC20(asset.assetAddress).safeTransfer(stxSender, value);

                // Update the deposit balance of the stx sender
                depositBalance[stxSender][assetId] -= value;
            }

            // refund the mempool exit fee to the stx sender
            Address.sendValue(payable(stxSender), mempoolExitFee);
        }

        // Remove STX from mempool
        _stxHashes.remove(stxHash);
        delete stxMap[stxHash];
        delete stxToProofId[stxHash];
        delete stxSenders[stxHash];

        emit STXDropped(stxHash, stxSender, block.timestamp);
        emit UnlockNotes(stxHash, stx.nullifiers);
    }
     */

    function withdrawMempoolExitFee() external nonReentrant {
        uint256 feeCollected = mempoolExitFeeCollected;
        mempoolExitFeeCollected = 0;
        Address.sendValue(payable(verificationTrackerService), feeCollected);
    }

    /**
    ///////////////////////////
    //// Read Functions //////
    ///////////////////////////
    function isSTXInMempool(uint256 stxHash) external view returns (bool) {
        return _stxHashes.contains(stxHash);
    }

    function getProofId(uint256 stxHash) external view returns (bytes32) {
        return stxToProofId[stxHash];
    }

    function isSTXProofVerified(uint256 stxHash) external view returns (bool) {
        bytes32 proofId = stxToProofId[stxHash];
        return INebraUpa(nebraVerifier).isProofVerified(proofId);
    }
     */

    ///////////////////////////
    //// Owner Functions //////
    ///////////////////////////
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function updateVerificationTrackerService(
        address newAddr
    ) external onlyOwner {
        verificationTrackerService = newAddr;
    }

    function updateGatewayContract(address newAddr) external onlyOwner {
        gateway = newAddr;
    }

    /// @notice Needs to be called immediately after the Labyrinth pool is deployed/upgraded, for the mempool to be able to interact with the pool
    function updatePoolAddress(address newPool) external onlyOwner {
        pool = IPool(newPool);
    }

    /**
    function updateMempoolExitFee(uint256 newFee) external onlyOwner {
        mempoolExitFee = newFee;
    }

    function updateNebraVerifier(address newAddr) external onlyOwner {
        nebraVerifier = newAddr;
    }
     */
}
