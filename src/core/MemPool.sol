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
import {IMempool, PreVerificationDetails, Action} from "src/interfaces/IMempool.sol";
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

    uint16 public constant DROP_TX_PENALTY_PERC = 800; // 8% penalty on the mempool exit fee for dropping the STX from mempool
    uint16 public constant PRECISION = 10000;

    function initialize(
        address pool_,
        uint256 proofSubAndMempoolExitFee_,
        address verificationTrackerService_,
        address nebraVerifier_,
        address gateway_
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        pool = IPool(pool_);
        proofSubAndMempoolExitFee = proofSubAndMempoolExitFee_;
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
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];

        stx.validityChecksBeforeAddingSTXToMempool(
            stxHashPI,
            pool,
            gateway,
            proofSubAndMempoolExitFee,
            totalProofSubAndMempoolExitFee,
            depositBalance
        );

        bytes32 proofId = keccak256(
            abi.encodePacked(
                preVerificationDetails.circuitId,
                preVerificationDetails.publicInputs
            )
        );

        stxProofIdSenderMap[stxHashPI][proofId] = msg.sender;

        emit STXAddedToMempool(stxHashPI, msg.sender, proofId, block.timestamp);
        emit LockNotes(stxHashPI, stx.nullifiers);
    }

    /// @notice Take STX out of the mempool and execute it
    function exitSTXFromMempool(
        uint256 stxHash,
        ShieldedTransaction calldata stx,
        bytes32 proofId
    ) external {
        // Check if the STX is in the mempool and ensures the proofId is corelated to the STX
        address stxSender = stxProofIdSenderMap[stxHash][proofId];
        if (stxSender == address(0)) {
            revert STXProofIdMismatchOrSTXAbsent(stxHash);
        }

        if (stx.hashSTX() != stxHash) {
            revert STXAndSTXHashMismatch();
        }

        // Onchain check with Nebra to ensure the proof is verified
        bool isProofValid = INebraUpa(nebraVerifier).isProofVerified(proofId);
        if (!isProofValid) {
            revert STXNotPreVerified(stxHash, proofId);
        }

        // Approve assets to the pool only for DEPOSIT tx
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            _handleDepositedAssets({
                pubAssets: stx.pubAssets,
                stxSender: stxSender,
                pool: address(pool),
                action: Action.EXIT
            });
        }

        delete stxProofIdSenderMap[stxHash][proofId];

        // Transact the STX
        pool.transact(stx, true);
        emit STXProcessed(stxHash, proofId, block.timestamp);
        emit UnlockNotes(stxHash, stx.nullifiers);
    }

    /// @notice Drops the STX from mempool if it's proof is not verified yet or has failed verification.
    /// @notice Refunds the user their deposit assets.
    function dropFromMempool(
        uint256 stxHash,
        ShieldedTransaction calldata stx,
        bytes32 proofId
    ) external nonReentrant {
        address stxSender = stxProofIdSenderMap[stxHash][proofId];
        // Check if the STX is in the mempool and ensures the proofId is corelated to the STX
        if (stxSender == address(0)) {
            revert STXNotInMempool(stxHash);
        }

        if (stx.hashSTX() != stxHash) {
            revert STXAndSTXHashMismatch();
        }

        // if proof is verified, don't allow refunds
        bool isProofValid = INebraUpa(nebraVerifier).isProofVerified(proofId);
        if (isProofValid) {
            revert STXNonRefundable(stxHash);
        }

        // refund deposited assets to the stx sender only for DEPOSIT tx
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            _handleDepositedAssets({
                pubAssets: stx.pubAssets,
                stxSender: stxSender,
                pool: address(pool),
                action: Action.DROP
            });
        }

        // Remove STX from mempool
        delete stxProofIdSenderMap[stxHash][proofId];

        emit STXDropped(stxHash, stxSender, block.timestamp);
        emit UnlockNotes(stxHash, stx.nullifiers);
    }

    function withdrawproofSubAndMempoolExitFee() external nonReentrant {
        uint256 feeCollected = totalProofSubAndMempoolExitFee;
        totalProofSubAndMempoolExitFee = 0;
        Address.sendValue(payable(verificationTrackerService), feeCollected);
    }

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

    function updateProofSubAndMempoolExitFee(
        uint256 newFee
    ) external onlyOwner {
        proofSubAndMempoolExitFee = newFee;
    }

    //////////////////////////////
    //// Internal Functions //////
    //////////////////////////////
    function _handleDepositedAssets(
        uint248[] memory pubAssets,
        address stxSender,
        address pool,
        Action action
    ) internal {
        for (uint i = 0; i < pubAssets.length; i++) {
            (uint24 assetId, uint224 value) = MempoolValidator.decodeAsset(
                pubAssets[i]
            );
            Asset memory asset = MempoolValidator.checkIfAssetValid(
                assetId,
                IPool(pool)
            );

            if (action == Action.DROP) {
                IERC20(asset.assetAddress).safeTransfer(stxSender, value);
            } else {
                IERC20(asset.assetAddress).forceApprove(pool, value);
            }

            // Update the deposit balance of the stx sender
            depositBalance[stxSender][assetId] -= value;
        }

        // refund the mempool exit fee to the stx sender after deducting the penalty
        Address.sendValue(
            payable(stxSender),
            (proofSubAndMempoolExitFee -
                ((DROP_TX_PENALTY_PERC * proofSubAndMempoolExitFee) /
                    PRECISION))
        );
    }
}
