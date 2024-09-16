// SPDX-LICENSE-Identifier: GPL
pragma solidity 0.8.24;

interface ICurvePool {
    function coins(uint256 i) external view returns (address);

    /// @notice Function to calculate the addition or reduction of token supply from a deposit (add liquidity) or withdrawal (remove liquidity) for 2 coin pools. This function does take fees into consideration.

    /// @dev creating different functions for different curve pools as the curvePool contract expects a static sized `amounts` array in it's `calc_token_amount(uint256[2],bool)`, etc func. signature. We cannot use dynamic array niether can we create the func. signature string dynamically using string manupulation for abi.encodeWithSignature("funcSign", params) as `abi.encodeWithSignature` expects a constant string at compile time.

    /// @param _amounts The amounts of tokens to be deposited or withdrawn (uint256[]).
    /// @param _is_deposit A boolean to indicate if the action is a deposit or withdrawal.
    /// @return lpTokenAmount The amount of LP tokens (uint256).
    function calc_token_amount(
        uint256[2] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256 lpTokenAmount);

    /// @notice Function to add liquidity to 2 coin pool.
    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount,
        address receiver
    ) external returns (uint256 lpTokenAmount);

    /// @notice Function to calculate the addition or reduction of token supply from a deposit (add liquidity) or withdrawal (remove liquidity) for 3 coin pools. This function does take fees into consideration.
    function calc_token_amount(
        uint256[3] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256 lpTokenAmount);

    /// @notice Function to add liquidity to 3 coin pool.
    function add_liquidity(
        uint256[3] memory _amounts,
        uint256 _min_mint_amount,
        address receiver
    ) external returns (uint256 lpTokenAmount);

    function calc_withdraw_one_coin(
        uint256 _burn_amount,
        int128 i
    ) external view returns (uint256 coinAmount);

    function remove_liquidity(
        uint256 _burn_amount,
        uint256[2] memory _min_amounts,
        address receiver
    ) external returns (uint256[2] memory coinsReceived);

    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received,
        address receiver
    ) external returns (uint256 coinsReceived);

    /// @notice Withdraw coins from the pool in an imbalanced amount
    /// @param _amounts List of amounts of underlying coins to withdraw
    /// @param _max_burn_amount Maximum amount of LP token to burn in the withdrawal
    /// @param _receiver Address that receives the withdrawn coins
    /// @return Actual amount of the LP token burned in the withdrawal
    function remove_liquidity_imbalance(
        uint256[2] memory _amounts,
        uint256 _max_burn_amount,
        address _receiver
    ) external returns (uint256);

    function balances(uint256 i) external view returns (uint256);

    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256 dy);
}
