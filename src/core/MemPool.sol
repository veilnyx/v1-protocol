// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, PreVerificationDetails, PubAsset} from "src/libraries/ShieldedTransaction.sol";
import {Asset, AssetLogic} from "src/libraries/Asset.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts-upgradeable/utils/EnumerableSet.sol";

contract Mempool is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using ShieldedTransactionLogic for ShieldedTransaction;
    using AssetLogic for Asset;
    using EnumerableSet for EnumerableSet.UintSet;

    IPool immutable _pool;
    EnumerableSet.UintSet public stxHashes;
    mapping(uint256 stxHash => mapping(bytes32 proofId => ShieldedTransaction stx)) public stxProofIdMap;
    
    // fees to be paid by the user for their STX to exit the mempool. This is a compensation for the verification tracker service that's responsible for taking the STX out of the mempool and verifying it. The fee is in wei.
    uint256 public mempoolExitFee;
    uint256 public mempoolExitFeeCollected;
    address public verificationTrackerService;

    error InvalidStx();
    error DuplicateStx(uint256 stxHash);
    error InactiveAsset(uint24 assetId);
    error UnsupportedAsset(uint24 assetId);
    error ZeroValue();
    error InsufficientFee(uint256 given, uint256 required);

    function initialize(address pool, uint256 mempoolExitFee_, address verificationTrackerService_) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        _pool = IPool(pool);
        mempoolExitFee = mempoolExitFee_;
        verificationTrackerService = verificationTrackerService_;
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
        assetId = uint24(bytes3(bytes31(stx.pubAsset)));
        // Extract last 28 bytes value
        value = uint224(stx.pubAsset);
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

        // Asset checks
        for (uint i = 0; i < stx.pubAssets.length; i++) {
            (uint24 assetId, uint224 value) = _decodeAsset(stx.pubAssets[i]);
            Asset asset = _checkIfAssetValid(assetId);

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

        // check if stx is already in mempool
        if (stxHashes.contains(stxHashPI)) {
            revert DuplicateStx(stxHashPI);
        }

        // Mempool exit fee check
        if(msg.value < mempoolExitFee) {
            revert InsufficientFee(msg.value, mempoolExitFee);
        }

        bytes32 proofId = ShieldedTransactionLogic.genNebraProofId(
            preVerificationDetails
        );
        stxProofIdMap[stxHashPI][proofId] = stx;
        stxHashes.add(stxHashPI);
        mempoolExitFeeCollected += mempoolExitFee;
    }

    /// @notice Take STX out of the mempool and execute it
    function exitSTXFromMempool(uint256 stxHash, bytes32 proofId) external {
        ShieldedTransaction memory stx = stxProofIdMap[stxHash][proofId];
        require(stxHashes.contains(stxHash), "STX not in mempool");

        // Remove STX from mempool
        stxHashes.remove(stxHash);
        delete stxProofIdMap[stxHash][proofId];

        // Transfer assets to the pool
        for (uint i = 0; i < stx.pubAssets.length; i++) {
            (uint24 assetId, uint224 value) = _decodeAsset(stx.pubAssets[i]);
            Asset asset = _checkIfAssetValid(assetId);

            IERC20(asset.assetAddress).forceApprove(
                address(_pool),
                value
            );
        }

        // Transact the STX
        _pool.transact(stx);
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
}
