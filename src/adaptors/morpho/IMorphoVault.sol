// SPDX-LICENSE-Identifier: GPL-3.0
pragma solidity 0.8.26;

/// @dev Morpho vaults are ERC-4626 compatible.
/// @notice Vaults are the entrypoint for lenders who wish to lend loan token. Each vault will only accept a single `loan token`. Vaults then distribute the received `loan token` deposits to various underlying markets. This makes Morpho a very modular system based on a shared base layer.
interface IMorphoVault {
    /// @notice Deposits assets of underlying token into the vault to mint vault shares to receiver.
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /// @notice Burns exactly shares vault shares from owner and sends the withdrawn assets of underlying tokens to receiver.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    /////////////////////////////
    //// View Functions /////////
    //////////////////////////////

    /// @notice This function returns the address of the underlying token used for the vault for accounting, depositing, withdrawing.
    function asset() external view returns (address assetTokenAddress);

    /// @notice This function returns the amount of shares that would be exchanged by the vault for the amount of assets provided.
    function convertToShares(
        uint256 assets
    ) external view returns (uint256 shares);

    /// @notice This function returns the amount of assets that would be exchanged by the vault for the amount of shares provided.
    function convertToAssets(
        uint256 shares
    ) external view returns (uint256 assets);
}
