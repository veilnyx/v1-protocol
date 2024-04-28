// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ZTransaction} from "../libraries/ZTransaction.sol";

interface IGateway is IAccount {
    function validateUserOp(
        PackedUserOperation calldata,
        bytes32,
        uint256
    ) external view returns (uint256);

    function handleUserOp(ZTransaction calldata ztx) external;

    function handleWrapAndDeposit(ZTransaction calldata ztx) external payable;

    function withdrawEntryPointDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external;

    function wToken() external view returns (address);

    function entryPoint() external view returns (address);
}
