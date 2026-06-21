// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransactionLogic.sol";
import {IWToken} from "../interfaces/IWToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IGateway} from "../interfaces/IGateway.sol";

contract Gateway is IGateway, Ownable {
    using SafeERC20 for IWToken;
    uint256 internal constant VALIDATION_SUCCEEDED = 0;

    IEntryPoint public immutable entryPoint;
    IPool public immutable pool;
    IWToken public immutable wToken;

    error InvalidEntryPoint(address entryPoint);
    error ZeroAddress();

    /// @custom:invariant ACCESS-5 Entrypoint to be the only caller of `validateUserOp` and `handleUserOp`
    modifier onlyEntryPoint() {
        if (msg.sender != address(entryPoint)) {
            revert InvalidEntryPoint(msg.sender);
        }
        _;
    }

    constructor(
        IEntryPoint entryPoint_,
        IWToken wToken_,
        IPool pool_
    ) Ownable(msg.sender) {
        if (
            address(entryPoint_) == address(0) ||
            address(wToken_) == address(0) ||
            address(pool_) == address(0)
        ) revert ZeroAddress();
        entryPoint = entryPoint_;
        pool = pool_;
        wToken = wToken_;
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
        pool.transact(stx);
    }

    function handleWrapAndDeposit(
        ShieldedTransaction calldata stx
    ) external payable {
        wToken.deposit{value: msg.value}();
        wToken.forceApprove(address(pool), msg.value);
        pool.transact(stx);
    }

    // This may not be needed as paymaster is always supposed to pay for gas
    // Added just for sake of recoverability of accidentally locked funds
    function withdrawEntryPointDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external onlyOwner {
        entryPoint.withdrawTo(withdrawAddress, amount);
    }

    // Intentionally empty: accepts native ETH for wrapping and gateway transfer flows.
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
