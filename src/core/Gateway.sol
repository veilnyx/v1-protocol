// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";
import {PreVerificationDetails} from "./Mempool.sol";
import {IWToken} from "../interfaces/IWToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IMempool} from "../interfaces/IMempool.sol";
import {IGateway} from "../interfaces/IGateway.sol";

contract Gateway is IGateway, Ownable {
    using SafeERC20 for IWToken;
    uint256 internal constant VALIDATION_SUCCEEDED = 0;
    uint256 internal constant VALIDATION_FAILED = 1;

    address public immutable entryPoint;
    address public immutable pool;
    address public immutable mempool;
    address public immutable wToken;

    error InvalidEntryPoint(address entryPoint);
    error ZeroAddress();

    /// @custom:invariant ACCESS-5 Entrypoint to be the only caller of `validateUserOp` and `handleUserOp`
    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) {
            revert InvalidEntryPoint(msg.sender);
        }
        _;
    }

    constructor(
        address entryPoint_,
        address wToken_,
        address pool_,
        address mempool_
    ) Ownable(msg.sender) {
        if (entryPoint_ == address(0) || wToken_ == address(0) || pool_ == address(0) || mempool_ == address(0)) revert ZeroAddress();
        entryPoint = entryPoint_;
        pool = pool_;
        wToken = wToken_;
        mempool = mempool_;
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
        ShieldedTransaction calldata stx,
        PreVerificationDetails calldata preVerificationDetails
    ) external onlyEntryPoint {
        if (preVerificationDetails.isPreVerified) {
            IMempool(mempool).addSTXToMempool(stx, preVerificationDetails);
        } else {
            IPool(pool).transact(stx, false);
        }
    }

    function handleWrapAndDeposit(
        ShieldedTransaction calldata stx
    ) external payable {
        IWToken(wToken).deposit{value: msg.value}();
        IWToken(wToken).forceApprove(pool, msg.value);
        IPool(pool).transact(stx, false);
    }

    // This may not be needed as paymaster is always supposed to pay for gas
    // Added just for sake of recoverability of accidentally locked funds
    function withdrawEntryPointDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) external onlyOwner {
        IEntryPoint(entryPoint).withdrawTo(withdrawAddress, amount);
    }

    receive() external payable {}
}
