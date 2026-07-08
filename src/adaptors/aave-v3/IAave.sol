// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

/// Interface for Aave Pool.
/// ETH Sepolia addr: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951

interface IAave {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}
