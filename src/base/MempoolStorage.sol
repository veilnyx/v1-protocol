// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransaction.sol";

abstract contract MempoolStorage {
    IPool public pool;
    mapping(uint256 => mapping(bytes32 => address)) public stxProofIdSenderMap;
    mapping(address stxSender => mapping(uint24 assetId => uint224 assetValue))
        public depositBalance;

    // fees to be paid by the user for their STX to exit the mempool. This is a compensation for the verification tracker service that's responsible for taking the STX out of the mempool and verifying it. The fee is in wei.
    uint256 public proofSubAndMempoolExitFee;
    uint256 public totalProofSubAndMempoolExitFee;
    address public verificationTrackerService;
    address public nebraVerifier;
    address public gateway;
}
