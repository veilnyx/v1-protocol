// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IScreener} from "src/interfaces/IScreener.sol";

contract MockScreener is IScreener {
    mapping(address => bool) public sanctioned;

    /// @notice Marks `account` as sanctioned (or clears it) for testing.
    function setSanctioned(address account, bool value) external {
        sanctioned[account] = value;
    }

    function isSanctioned(
        address account
    ) public view override returns (bool) {
        return sanctioned[account];
    }
}
