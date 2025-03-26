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
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType, PreVerificationDetails, PubAsset} from "src/libraries/ShieldedTransaction.sol";
import {Asset, AssetLogic, AssetType} from "src/libraries/Asset.sol";
import {INebraUpa} from "../interfaces/INebraUpa.sol";

contract Mempool is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuard
{
    using ShieldedTransactionLogic for ShieldedTransaction;
    using AssetLogic for Asset;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    // @todo: Move storage outside of the upgradeable contract
    IPool public _pool;
    EnumerableSet.UintSet internal _stxHashes;
    mapping(uint256 stxHash => bytes32) public stxToProofId;
    mapping(uint256 stxHash => ShieldedTransaction) public stxMap;
    mapping(uint256 stxHash => address) public stxSenders;

    // fees to be paid by the user for their STX to exit the mempool. This is a compensation for the verification tracker service that's responsible for taking the STX out of the mempool and verifying it. The fee is in wei.
    uint256 public mempoolExitFee;
    uint256 public mempoolExitFeeCollected;
    address public verificationTrackerService;
    address public nebraVerifier;

    error InvalidStx();
    error DuplicateStx(uint256 stxHash);
    error STXNotInMempool(uint256 stxHash);
    error STXAndProofIdMismatch();
    error InactiveAsset(uint24 assetId);
    error UnsupportedAsset(uint24 assetId);
    error ZeroValue();
    error InsufficientFee(uint256 given, uint256 required);
    error STXNonRefundable(uint256 stxHash);

    event STXAddedToMempool(
        uint256 indexed stxHash,
        address indexed sender,
        bytes32 proofId,
        uint256 timestamp
    );

    event STXProcessed(
        uint256 indexed stxHash,
        bytes32 indexed proofId,
        uint256 timestamp
    );

    event STXRefunded(
        uint256 indexed stxHash,
        address indexed sender,
        uint256 timestamp
    );

    function initialize(
        address pool,
        uint256 mempoolExitFee_,
        address verificationTrackerService_,
        address nebraVerifier_
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        _pool = IPool(pool);
        mempoolExitFee = mempoolExitFee_;
        verificationTrackerService = verificationTrackerService_;
        nebraVerifier = nebraVerifier_;
    }

    ///////////////////////////
    //// Private Functions ////
    ///////////////////////////
    function _checkIfAssetValid(
        uint24 assetId
    ) internal view returns (Asset memory) {
        Asset memory asset = _pool.getAsset(assetId);
        if (!asset.isActive) {
            revert InactiveAsset(asset.id);
        }

        if (asset.assetType != AssetType.ERC20) {
            revert UnsupportedAsset(asset.id);
        }

        return asset;
    }

    function _decodeAsset(
        uint248 pubAsset
    ) internal pure returns (uint24 assetId, uint224 value) {
        // Extract first 3 bytes assetId
        assetId = uint24(bytes3(bytes31(pubAsset)));
        // Extract last 28 bytes value
        value = uint224(pubAsset);
    }

    ///////////////////////////
    //// External Functions ///
    ///////////////////////////
    /// @dev Add a shielded transaction to the mempool
    /// @dev Will also receive the mempool exit fee from the user, which needs to be refunded to the verification tracker service
    function addSTXToMempool(
        ShieldedTransaction calldata stx,
        PreVerificationDetails memory preVerificationDetails
    ) external payable whenNotPaused {
        address stxSender = msg.sender;
        uint256 stxHashPI = preVerificationDetails.publicInputs[2];

        if (stx.hash() != stxHashPI) {
            revert InvalidStx();
        }

        // check if stx is already in mempool
        if (_stxHashes.contains(stxHashPI)) {
            revert DuplicateStx(stxHashPI);
        }

        // Mempool exit fee check
        if (msg.value < mempoolExitFee) {
            revert InsufficientFee(msg.value, mempoolExitFee);
        }

        // Asset checks
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            for (uint i = 0; i < stx.pubAssets.length; i++) {
                (uint24 assetId, uint224 value) = _decodeAsset(
                    stx.pubAssets[i]
                );
                Asset memory asset = _checkIfAssetValid(assetId);

                if (value == 0) {
                    revert ZeroValue();
                }

                // Transfer the right amt of assets being deposited to the pool
                IERC20(asset.assetAddress).safeTransferFrom(
                    stxSender,
                    address(this),
                    value
                );
            }
        }

        bytes32 proofId = ShieldedTransactionLogic.genNebraProofId(
            preVerificationDetails
        );
        stxToProofId[stxHashPI] = proofId;
        stxMap[stxHashPI] = stx;
        stxSenders[stxHashPI] = stxSender;
        _stxHashes.add(stxHashPI);
        mempoolExitFeeCollected += mempoolExitFee;

        emit STXAddedToMempool(stxHashPI, stxSender, proofId, block.timestamp);
    }

    /// @notice Take STX out of the mempool and execute it
    function exitSTXFromMempool(uint256 stxHash) external {
        if (!_stxHashes.contains(stxHash)) {
            revert STXNotInMempool(stxHash);
        }

        ShieldedTransaction memory stx = stxMap[stxHash];
        bytes32 proofId = stxToProofId[stxHash];

        // Remove STX from mempool
        _stxHashes.remove(stxHash);
        delete stxMap[stxHash];
        delete stxToProofId[stxHash];
        delete stxSenders[stxHash];

        // Approve assets to the pool
        for (uint i = 0; i < stx.pubAssets.length; i++) {
            (uint24 assetId, uint224 value) = _decodeAsset(stx.pubAssets[i]);
            Asset memory asset = _checkIfAssetValid(assetId);

            IERC20(asset.assetAddress).forceApprove(address(_pool), value);
        }

        // Transact the STX
        _pool.transact(stx);
        emit STXProcessed(stxHash, proofId, block.timestamp);
    }

    /// @notice Refund the user their assets if their STX fails proof verification.
    /// @notice This also allows users to refund their assets if they decide to exit the mempool before their STX is verified.
    function refund(uint256 stxHash) external nonReentrant {
        if (_stxHashes.contains(stxHash)) {
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

        // Remove STX from mempool
        _stxHashes.remove(stxHash);
        delete stxMap[stxHash];
        delete stxToProofId[stxHash];
        delete stxSenders[stxHash];

        // refund deposited assets to the stx sender
        for (uint i = 0; i < stx.pubAssets.length; i++) {
            (uint24 assetId, uint224 value) = _decodeAsset(stx.pubAssets[i]);
            Asset memory asset = _checkIfAssetValid(assetId);

            IERC20(asset.assetAddress).safeTransfer(stxSender, value);
        }

        // refund the mempool exit fee to the stx sender
        Address.sendValue(payable(stxSender), mempoolExitFee);

        emit STXRefunded(stxHash, stxSender, block.timestamp);
    }

    function withdrawMempoolExitFee() external nonReentrant {
        uint256 feeCollected = mempoolExitFeeCollected;
        mempoolExitFeeCollected = 0;
        Address.sendValue(payable(verificationTrackerService), feeCollected);
    }

    ///////////////////////////
    //// Owner Functions //////
    ///////////////////////////
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function updateMempoolExitFee(uint256 newFee) external onlyOwner {
        mempoolExitFee = newFee;
    }

    function changeVerificationTrackerService(
        address newAddr
    ) external onlyOwner {
        verificationTrackerService = newAddr;
    }
}
