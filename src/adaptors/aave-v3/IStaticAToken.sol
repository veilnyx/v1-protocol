// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

interface IStaticAToken {
    function aToken() external view returns (address);

    /**
     * @notice Deposits `ASSET` in the Aave protocol and mints static aTokens to msg.sender
     * @param assets The amount of underlying `ASSET` to deposit (e.g. deposit of 100 USDC)
     * @param receiver The address that will receive the static aTokens
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     * @param depositToAave bool
     * - `true` if the msg.sender comes with underlying tokens (e.g. USDC)
     * - `false` if the msg.sender comes already with aTokens (e.g. aUSDC)
     * @return uint256 The amount of StaticAToken minted, static balance
     **/
    function deposit(
        uint256 assets,
        address receiver,
        uint16 referralCode,
        bool depositToAave
    ) external returns (uint256);

    /**
     * @notice Burns `amount` of static aToken, with receiver receiving the corresponding amount of `ASSET`
     * @param shares The amount to withdraw, in static balance of StaticAToken
     * @param receiver The address that will receive the amount of `ASSET` withdrawn from the Aave protocol
     * @param withdrawFromAave bool
     * - `true` for the receiver to get underlying tokens (e.g. USDC)
     * - `false` for the receiver to get aTokens (e.g. aUSDC)
     * @return amountToBurn: StaticATokens burnt, static balance
     * @return amountToWithdraw: underlying/aToken send to `receiver`, dynamic balance
     **/
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        bool withdrawFromAave
    ) external returns (uint256, uint256);
}
