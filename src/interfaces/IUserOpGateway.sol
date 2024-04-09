// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {ZTransaction} from "../libraries/ZTransaction.sol";

interface IUserOpGateway is IAccount {
    function relayZTransaction(ZTransaction calldata ztx) external;

    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external;

    function entryPoint() external view returns (address);
}
