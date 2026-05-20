// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTree.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
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
}
