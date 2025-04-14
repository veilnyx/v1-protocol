// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";

abstract contract MempoolStorage {
    IPool public pool;
    EnumerableSet.UintSet internal _stxHashes;
    mapping(uint256 => bytes32) public stxToProofId;
    mapping(uint256 => ShieldedTransaction) public stxMap;
    mapping(uint256 => address) public stxSenders;

    // fees to be paid by the user for their STX to exit the mempool. This is a compensation for the verification tracker service that's responsible for taking the STX out of the mempool and verifying it. The fee is in wei.
    uint256 public mempoolExitFee;
    uint256 public mempoolExitFeeCollected;
    address public verificationTrackerService;
    address public nebraVerifier;
    address public gateway;
}
