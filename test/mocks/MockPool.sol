// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTreeLogic.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {MockVerifier} from "test/mocks/MockVerifier.sol";

contract MockPool is Pool {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;

    function mock_verifier(address verifier_) public {
        verifier = IVerifier(verifier_);
        _commitmentTree.verifier = IVerifier(verifier_);
    }

    function mock_queueCommitments(uint256[] memory commitments) public {
        _commitmentTree.queueLeaves(commitments);
    }

    function getDepositUsd(
        ShieldedTransaction calldata stx
    ) public view returns (uint256 depositUsd) {
        return super._getDepositUsd(stx);
    }

    function mock_validateNoDuplicatePubAssets(
        ShieldedTransaction calldata stx
    ) external pure {
        _validateNoDuplicatePubAssets(stx);
    }

    function getQueueRawState()
        external
        view
        returns (
            uint32 startIdx,
            uint32 endIdx,
            uint32 nextLeaf,
            uint8 queueSz,
            uint8 rootIdx
        )
    {
        startIdx = _commitmentTree.queueStartIndex;
        endIdx = _commitmentTree.queueEndIndex;
        nextLeaf = _commitmentTree.nextLeafIndex;
        queueSz = _commitmentTree.queueSize;
        rootIdx = _commitmentTree.currentRootIndex;
    }
}
