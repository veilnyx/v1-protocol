// SPDX-License-Identifier: LicenseRef-BUSL

pragma solidity 0.8.24;

interface IRocketSwapRouter {
    /// @notice Executes a swap of ETH to rETH
    /// @param _uniswapPortion The portion to swap via Uniswap
    /// @param _balancerPortion The portion to swap via Balancer
    /// @param _minTokensOut Swap will revert if at least this amount of rETH is not output
    /// @param _idealTokensOut If the protocol can provide a better swap than this, it will swap as much as possible that way
    function swapTo(
        uint256 _uniswapPortion,
        uint256 _balancerPortion,
        uint256 _minTokensOut,
        uint256 _idealTokensOut
    ) external payable;

    /// @notice Executes a swap of rETH to ETH. User should approve this contract to spend their rETH before calling.
    /// @param _uniswapPortion The portion to swap via Uniswap
    /// @param _balancerPortion The portion to swap via Balancer
    /// @param _minTokensOut Swap will revert if at least this amount of ETH is not output
    /// @param _idealTokensOut If the protocol can provide a better swap than this, it will swap as much as possible that way
    function swapFrom(
        uint256 _uniswapPortion,
        uint256 _balancerPortion,
        uint256 _minTokensOut,
        uint256 _idealTokensOut,
        uint256 _tokensIn
    ) external;
}
