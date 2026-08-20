// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Testnet-only faucet so the team can self-serve the vault's test USDC
///         without an admin mint per request. Refuses nothing but a busy hour.
contract TestUsdcFaucet {
    IERC20 public immutable token;
    uint256 public constant DRIP = 5_000e6; // 5,000 test USDC
    mapping(address => uint256) public lastDrip;

    constructor(IERC20 token_) {
        token = token_;
    }

    function drip() external {
        require(block.timestamp - lastDrip[msg.sender] >= 1 hours, "one drip per hour");
        lastDrip[msg.sender] = block.timestamp;
        token.transfer(msg.sender, DRIP);
    }
}
