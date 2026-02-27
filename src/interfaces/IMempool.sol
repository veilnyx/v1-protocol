// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";

struct PreVerificationDetails {
    bool isPreVerified;
    bytes32 circuitId;
    uint256[] publicInputs;
    address verifierAddr;
}

enum Action {
    DROP,
    EXIT
}

interface IMempool {
    error STXNotInMempool(uint256 stxHash);
    error STXProofIdMismatchOrSTXAbsent(uint256 stxHash);
    error STXAndSTXHashMismatch();
    error STXNotPreVerified(uint256 stxHash, bytes32 proofId);
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

    event STXDropped(
        uint256 indexed stxHash,
        address indexed sender,
        uint256 timestamp
    );

    event LockNotes(uint256 indexed stxHash, uint256[] nullifiers);
    event UnlockNotes(uint256 indexed stxHash, uint256[] nullifiers);
    event ProofAggregationFeeUpdated(uint256 newFee);

    function initialize(
        address pool_,
        uint256 proofSubAndMempoolExitFee_,
        address verificationTrackerService_,
        address nebraVerifier_,
        address gateway_
    ) external;

    function addSTXToMempool(
        ShieldedTransaction calldata stx,
        PreVerificationDetails calldata preVerificationDetails
    ) external payable;

    function exitSTXFromMempool(
        uint256 stxHash,
        ShieldedTransaction calldata stx,
        bytes32 proofId
    ) external;

    function dropFromMempool(
        uint256 stxHash,
        ShieldedTransaction calldata stx,
        bytes32 proofId
    ) external;

    function withdrawproofSubAndMempoolExitFee() external;

    function updateVerificationTrackerService(address newAddr) external;

    function updatePoolAddress(address newPool) external;

    function updateProofSubAndMempoolExitFee(uint256 newFee) external;
}
