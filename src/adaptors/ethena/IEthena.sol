// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

interface IEthena {
    /// @notice This function deposits assets of underlying tokens into the vault and grants ownership of shares to receiver.
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    function maxRedeem(address owner) external returns (uint256);

    function cooldownShares(uint256 shares) external returns (uint256 assets);

    function unstake(address receiver) external;

    function cooldownDuration() external view returns (uint24);
}
