// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";
import {IWToken} from "./IWToken.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

interface IGateway is IAccount {
    function validateUserOp(
        PackedUserOperation calldata,
        bytes32,
        uint256
    ) external view returns (uint256);

    function handleUserOp(ShieldedTransaction calldata stx) external;

    function handleWrapAndDeposit(
        ShieldedTransaction calldata stx
    ) external payable;

    function withdrawEntryPointDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external;

    function wToken() external view returns (IWToken);

    function entryPoint() external view returns (IEntryPoint);
}
