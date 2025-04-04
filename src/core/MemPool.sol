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
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType, PubAsset} from "src/libraries/ShieldedTransaction.sol";
import {Asset, AssetLogic, AssetType} from "src/libraries/Asset.sol";
import {INebraUpa} from "../interfaces/INebraUpa.sol";
import {console} from "forge-std/console.sol";

contract Mempool is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuard,
    IMempool
{
    using ShieldedTransactionLogic for ShieldedTransaction;
    using AssetLogic for Asset;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    // @todo: Move storage outside of the upgradeable contract
    IPool public pool;
    EnumerableSet.UintSet internal _stxHashes;
    mapping(uint256 stxHash => bytes32) public stxToProofId;
    mapping(uint256 stxHash => ShieldedTransaction) public stxMap;
    mapping(uint256 stxHash => address) public stxSenders;

    // fees to be paid by the user for their STX to exit the mempool. This is a compensation for the verification tracker service that's responsible for taking the STX out of the mempool and verifying it. The fee is in wei.
    uint256 public mempoolExitFee;
    uint256 public mempoolExitFeeCollected;
    address public verificationTrackerService;
    address public nebraVerifier;
    address public gateway;

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

        _validityChecksBeforeAddingSTXToMempool(stx, stxHashPI);

        // Transfer deposit assets from sender's wallet to the mempool
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            for (uint i = 0; i < stx.pubAssets.length; i++) {
                (uint24 assetId, uint224 value) = _decodeAsset(
                    stx.pubAssets[i]
                );
                Asset memory asset = _checkIfAssetValid(assetId);

                // Transfer the right amt of assets being deposited to the pool
                IERC20(asset.assetAddress).safeTransferFrom(
                    stxSender,
                    address(this),
                    value
                );
            }
        }

        bytes32 proofId = genNebraProofId(preVerificationDetails);
        console.log("ProofId generated onchain: ");
        console.logBytes32(proofId);

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

        console.log("ProofId being verified onchain: ");
        console.logBytes32(proofId);

        // Onchain check with Nebra to ensure the proof is verified
        bool isProofValid = INebraUpa(nebraVerifier).isProofVerified(proofId);
        if (!isProofValid) {
            revert STXNotPreVerified(stxHash, proofId);
        }

        // Remove STX from mempool
        _stxHashes.remove(stxHash);
        delete stxMap[stxHash];
        delete stxToProofId[stxHash];
        delete stxSenders[stxHash];

        // Approve assets to the pool
        for (uint i = 0; i < stx.pubAssets.length; i++) {
            (uint24 assetId, uint224 value) = _decodeAsset(stx.pubAssets[i]);
            Asset memory asset = _checkIfAssetValid(assetId);

            IERC20(asset.assetAddress).forceApprove(address(pool), value);
        }

        // Transact the STX
        pool.transact(stx, true);
        emit STXProcessed(stxHash, proofId, block.timestamp);
        emit UnlockNotes(stxHash, stx.nullifiers);
    }

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

        emit STXDropped(stxHash, stxSender, block.timestamp);
        emit UnlockNotes(stxHash, stx.nullifiers);
    }

    function withdrawMempoolExitFee() external nonReentrant {
        uint256 feeCollected = mempoolExitFeeCollected;
        mempoolExitFeeCollected = 0;
        Address.sendValue(payable(verificationTrackerService), feeCollected);
    }

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

    ///////////////////////////
    //// Owner Functions //////
    ///////////////////////////
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function updateMempoolExitFee(uint256 newFee) external onlyOwner {
        mempoolExitFee = newFee;
    }

    function updateVerificationTrackerService(
        address newAddr
    ) external onlyOwner {
        verificationTrackerService = newAddr;
    }

    function updateGatewayContract(address newAddr) external onlyOwner {
        gateway = newAddr;
    }

    function updateNebraVerifier(address newAddr) external onlyOwner {
        nebraVerifier = newAddr;
    }

    /// @notice Needs to be called immediately after the Labyrinth pool is deployed/upgraded, for the mempool to be able to interact with the pool
    function updatePoolAddress(address newPool) external onlyOwner {
        pool = IPool(newPool);
    }

    ///////////////////////////
    //// Private Functions ////
    ///////////////////////////
    function _checkIfAssetValid(
        uint24 assetId
    ) internal view returns (Asset memory) {
        Asset memory asset = pool.getAsset(assetId);
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

    /// @notice Generates a proof id for Nebra proof verification
    /// @dev Written in assembly because abi.encodePacked was causing stack too deep error due to large number of inputs (public inputs)
    function genNebraProofId(
        PreVerificationDetails memory preVerificationDetails
    ) public pure returns (bytes32) {
        // Pre-allocate memory for exact encoding pattern
        bytes memory encoded = new bytes(544);

        assembly {
            let ptr := add(encoded, 32)

            // Store circuitId with proper padding
            mstore(ptr, mload(add(preVerificationDetails, 32)))
            ptr := add(ptr, 32)

            // Get publicInputs array pointer
            // Add 64 instead of 32 to skip over the bool field (32 bytes) and access circuitId
            let publicInputsPtr := mload(add(preVerificationDetails, 64))

            // Check array length (first 32 bytes of array contain length)
            let arrayLength := mload(publicInputsPtr)
            if iszero(eq(arrayLength, 16)) {
                revert(0, 0) // Revert if not exactly 16 inputs
            }

            // Skip array length prefix and copy inputs
            publicInputsPtr := add(publicInputsPtr, 32)
            for {
                let i := 0
            } lt(i, 16) {
                i := add(i, 1)
            } {
                mstore(ptr, mload(add(publicInputsPtr, mul(i, 32))))
                ptr := add(ptr, 32)
            }
        }

        return keccak256(encoded);
    }

    function _validityChecksBeforeAddingSTXToMempool(
        ShieldedTransaction calldata stx,
        uint256 stxHashPI
    ) internal {
        if (address(pool) == address(0)) {
            revert LabyrinthPoolAddrNotInitialized();
        }

        // validate the correlation btw the stx and public inputs
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

        // Non-deposit STX are only supported through Account Abstraction (ERC4337) infra
        // This is done to enforce privacy by not exposing the user's public address in the tx traces and to manage fee reimbursement to paymaster and verification tracker service by the Laby pool, using the `stx.feeData`.
        if (stx.txType != ShieldedTransactionType.DEPOSIT) {
            // msg.sender should only be the Gateway contract
            if (msg.sender != gateway) {
                revert NonDepositTxReceivedFromPublicAddr(msg.sender);
            }
        }

        // Asset checks and transfer for DEPOSIT tx
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            for (uint i = 0; i < stx.pubAssets.length; i++) {
                (uint24 assetId, uint224 value) = _decodeAsset(
                    stx.pubAssets[i]
                );
                Asset memory asset = _checkIfAssetValid(assetId);

                if (value == 0) {
                    revert ZeroValue();
                }
            }
        }
    }
}
