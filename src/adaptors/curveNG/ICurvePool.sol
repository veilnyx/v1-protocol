// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

interface ICurvePool {
    /////////////////////////////////
    /////// Deposit functions ///////
    /////////////////////////////////

    /// @notice Function to add liquidity to 2 coin pool.
    function add_liquidity(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount,
        address receiver
    ) external returns (uint256 lpTokenAmount);

    /// @notice Function to add liquidity to 3 coin pool.
    function add_liquidity(
        uint256[3] memory _amounts,
        uint256 _min_mint_amount,
        address receiver
    ) external returns (uint256 lpTokenAmount);

    ///////////////////////////////////
    /////// Withdraw functions ///////
    /////////////////////////////////

    /// @notice Withdraw underlying tokens in a balanced ratio from a 2 coin pool.
    function remove_liquidity(
        uint256 _burn_amount,
        uint256[2] memory _min_amounts,
        address receiver
    ) external returns (uint256[2] memory coinsReceived);

    /// @notice Withdraw underlying tokens in a balanced ration from a 3 coin pool.
    function remove_liquidity(
        uint256 _burn_amount,
        uint256[3] memory _min_amounts,
        address receiver
    ) external returns (uint256[3] memory coinsReceived);

    /// @notice Withdraw coins from a 2 coin pool in an imbalanced amount
    /// @param _amounts List of amounts of underlying coins to withdraw
    /// @param _max_burn_amount Maximum amount of LP token to burn in the withdrawal
    /// @param _receiver Address that receives the withdrawn coins
    /// @return Actual amount of the LP token burned in the withdrawal
    function remove_liquidity_imbalance(
        uint256[2] memory _amounts,
        uint256 _max_burn_amount,
        address _receiver
    ) external returns (uint256);

    /// @notice Withdraw coins from a 3 coin pool in an imbalanced amount
    function remove_liquidity_imbalance(
        uint256[3] memory _amounts,
        uint256 _max_burn_amount,
        address _receiver
    ) external returns (uint256);

    /// @notice Function to withdraw a single coin in return of the pool lp token for both 2 & 3 coin pool.
    /// @dev This function has the common func. signature for both 2 & 3 coin pools.
    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received,
        address receiver
    ) external returns (uint256 coinsReceived);

    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        address receiver
    ) external returns (uint256 dy);

    /////////////////////////////////
    /////// View functions //////////
    /////////////////////////////////
    function coins(uint256 i) external view returns (address);

    function balances(uint256 i) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    /// @notice Function to calculate the addition or reduction of token supply from a deposit (add liquidity) or withdrawal (remove liquidity) for 2 coin pools. This function does take fees into consideration.

    /// @dev creating different functions for different curve pools as the curvePool contract expects a static sized `amounts` array in it's `calc_token_amount(uint256[2],bool)`, etc func. signature. We cannot use dynamic array niether can we create the func. signature string dynamically using string manupulation for abi.encodeWithSignature("funcSign", params) as `abi.encodeWithSignature` expects a constant string at compile time.

    /// @param _amounts The amounts of tokens to be deposited or withdrawn (uint256[]).
    /// @param _is_deposit A boolean to indicate if the action is a deposit or withdrawal.
    /// @return lpTokenAmount The amount of LP tokens (uint256).
    function calc_token_amount(
        uint256[2] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256 lpTokenAmount);

    /// @notice Function to calculate the addition or reduction of token supply from a deposit (add liquidity) or withdrawal (remove liquidity) for 3 coin pools. This function does take fees into consideration.
    function calc_token_amount(
        uint256[3] memory _amounts,
        bool _is_deposit
    ) external view returns (uint256 lpTokenAmount);

    /// @notice Calculate the amount received when withdrawing a single coin.
    function calc_withdraw_one_coin(
        uint256 _burn_amount,
        int128 i
    ) external view returns (uint256 coinAmount);
}
