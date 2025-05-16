// SPDX-License-Identifier: GPL
pragma solidity 0.8.26;

interface IBeefyVault {
    /// @notice Returns the amount of "want" (i.e. underlying farm token) stored in the vault and strategy and yield source as an integer.
    function balance() external view returns (uint256);

    /// @notice Returns the total amount of mooTokens minted as an integer, which are always displayed as 18 decimal token.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the address of the underlying farm token (LP token) a certain Beefy vault requires
    function want() external view returns (address);

    /// @notice Function to deposit want tokens into the vault.
    /// @param _amount Amount of tokens to deposit.
    function deposit(uint256 _amount) external;

    /// @notice Function to withdraw tokens from the vault.
    /// @param _amount Amount of tokens to withdraw.
    function withdraw(uint256 _amount) external;
}
