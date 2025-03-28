// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";
import {IWToken} from "../interfaces/IWToken.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IGateway} from "../interfaces/IGateway.sol";

contract Gateway is IGateway, Ownable {
    uint256 internal constant VALIDATION_SUCCEEDED = 0;
    uint256 internal constant VALIDATION_FAILED = 1;

    address internal immutable _entryPoint;
    address internal immutable _pool;
    address internal immutable _wToken;

    error InvalidEntryPoint(address entryPoint);

    modifier onlyEntryPoint() {
        if (msg.sender != _entryPoint) {
            revert InvalidEntryPoint(msg.sender);
        }
        _;
    }

    constructor(
        address entryPoint_,
        address wToken_,
        address pool_
    ) Ownable(msg.sender) {
        _entryPoint = entryPoint_;
        _pool = pool_;
        _wToken = wToken_;
    }

    /// @dev `missingAccountFunds` is always expected to be 0 since paymaster
    /// pays for the tx and extracts gas+protocol fee
    function validateUserOp(
        PackedUserOperation calldata,
        bytes32,
        uint256
    ) external view onlyEntryPoint returns (uint256 validationData) {
        return VALIDATION_SUCCEEDED;
    }

    function handleUserOp(
        ShieldedTransaction calldata stx
    ) external onlyEntryPoint {
        IPool(_pool).transact(stx, false);
    }

    function handleWrapAndDeposit(
        ShieldedTransaction calldata stx
    ) external payable {
        IWToken(_wToken).deposit{value: msg.value}();
        IWToken(_wToken).approve(_pool, msg.value);
        IPool(_pool).transact(stx, false);
    }

    // This may not be needed as paymaster is always supposed to pay for gas
    // Added just for sake of recoverability of accidentally locked funds
    function withdrawEntryPointDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external onlyOwner {
        IEntryPoint(_entryPoint).withdrawTo(withdrawAddress, amount);
    }

    function wToken() external view returns (address) {
        return _wToken;
    }

    function entryPoint() external view returns (address) {
        return _entryPoint;
    }

    receive() external payable {}
}
