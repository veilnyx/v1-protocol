// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";

struct PreVerificationDetails {
    bool isPreVerified;
    bytes32 circuitId;
    uint256[] publicInputs;
    address verifierAddr;
}

interface IMempool {
    error LabyrinthPoolAddrNotInitialized();
    error InvalidStx();
    error DuplicateStx(uint256 stxHash);
    error STXNotInMempool(uint256 stxHash);
    error STXAndProofIdMismatch();
    error InactiveAsset(uint24 assetId);
    error UnsupportedAsset(uint24 assetId);
    error ZeroValue();
    error InsufficientFee(uint256 given, uint256 required);
    error STXNotPreVerified(uint256 stxHash, bytes32 proofId);
    error STXNonRefundable(uint256 stxHash);
    error NonDepositTxReceivedFromPublicAddr(address sender);

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

    event STXDropped(
        uint256 indexed stxHash,
        address indexed sender,
        uint256 timestamp
    );

    event LockNotes(uint256 indexed stxHash, uint256[] nullifiers);
    event UnlockNotes(uint256 indexed stxHash, uint256[] nullifiers);

    function initialize(
        address pool_,
        uint256 mempoolExitFee_,
        address verificationTrackerService_,
        address nebraVerifier_,
        address gateway_
    ) external;

    function genNebraProofId(
        PreVerificationDetails calldata preVerificationDetails
    ) external pure returns (bytes32);

    function addSTXToMempool(
        ShieldedTransaction calldata stx,
        PreVerificationDetails calldata preVerificationDetails
    ) external payable;

    function exitSTXFromMempool(uint256 stxHash) external;

    function dropFromMempool(uint256 stxHash) external;

    function withdrawMempoolExitFee() external;

    function isSTXInMempool(uint256 stxHash) external view returns (bool);

    function getProofId(uint256 stxHash) external view returns (bytes32);

    function isSTXProofVerified(uint256 stxHash) external view returns (bool);

    function updateMempoolExitFee(uint256 newFee) external;

    function updateVerificationTrackerService(address newAddr) external;

    function updatePoolAddress(address newPool) external;

    /**
    function mempoolExitFee() external view returns (uint256);

    function mempoolExitFeeCollected() external view returns (uint256);

    function verificationTrackerService() external view returns (address);

    function nebraVerifier() external view returns (address);

    function stxMap(
        uint256 stxHash
    ) external view returns (ShieldedTransaction memory);

    function stxSenders(uint256 stxHash) external view returns (address);
     */
}
