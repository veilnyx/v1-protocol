// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

/// Interface for Aave Token.

interface IAToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
