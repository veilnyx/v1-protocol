// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {UserOperation} from "@account-abstraction/contracts/interfaces/UserOperation.sol";

abstract contract PoolAccount is IAccount {
    uint256 internal constant VALIDATION_SUCCEEDED = 0;
    uint256 internal constant VALIDATION_FAILED = 1;

    error InvalidEntryPoint(address entryPoint);

    /// @dev `missingAccountFunds` is always expected to be 0 since paymaster
    /// pays for the tx and extracts gas+protocol fee
    function validateUserOp(
        UserOperation calldata,
        bytes32,
        uint256
    ) external virtual override returns (uint256 validationData) {
        if (msg.sender != _entryPoint()) {
            revert InvalidEntryPoint(msg.sender);
        }
        return VALIDATION_SUCCEEDED;
    }

    // @todo This may not be needed as paymaster pays gas always.
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public {
        _authorizeWithdrawAccountDeposit();
        IEntryPoint(_entryPoint()).withdrawTo(withdrawAddress, amount);
    }

    function _entryPoint() internal virtual returns (address);

    function _authorizeWithdrawAccountDeposit() internal virtual;
}
