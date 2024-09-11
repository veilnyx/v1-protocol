// SPDX-LICENSE-Identifier: GPL
pragma solidity 0.8.24;

interface ICurvePool {
    /// @notice Function to calculate the addition or reduction of token supply from a deposit (add liquidity) or withdrawal (remove liquidity). This function does take fees into consideration.
    /// @param _amounts The amounts of tokens to be deposited or withdrawn (uint256[]).
    /// @return lpTokenAmount The amount of LP tokens (uint256).
    function calc_token_amount(
        uint256[] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256 lpTokenAmount);

    /// @notice Function to add liquidity to the pool.
    function add_liquidity(
        uint256[] memory _amounts,
        uint256 _min_mint_amount,
        address receiver
    ) external returns (uint256 lpTokenAmount);
}
