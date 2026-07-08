// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/AssetLogic.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {ICurvePool} from "./ICurvePool.sol";
import {AssetAmount} from "../../interfaces/IAdaptor.sol";
import {IPool} from "../../interfaces/IPool.sol";

struct Payload {
    address curvePool;
    uint8 action;
    uint8 withdrawType;
    uint8 singleCoinIndex;
    uint256[] underlyingTokenAmts;
    uint256 slippageBps;
}

contract CurveNGAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    enum WithdrawType {
        BALANCED,
        SINGLE,
        IMBALANCED
    }

    struct PoolUnderlyingTokensInfo {
        address[] coins;
        uint256[] balances;
        uint24[] assetIds;
        uint8[] indexes;
    }

    error InvalidCoinCount(uint256 nCoins);
    error InvalidCoinIndex(uint8 coinIndex);
    error InvalidSlippageBps(uint256 slippageBps, uint256 maxBps);
    error InvalidUnderlyingTokenAmountLength(uint256 actual, uint256 expected);
    error AssetNotSupportedByPool(address asset, ICurvePool curvePool);

    uint8 constant ACTION_SUPPLY = 0;
    uint8 constant ACTION_WITHDRAW = 1;
    uint256 constant BPS_PRECISION = 100_00;

    // Intentionally empty: no adaptor-specific constructor logic beyond base initialization.
    // solhint-disable-next-line no-empty-blocks
    constructor(IPool pool_) AdaptorBase(pool_) {}

    function handleAssets(
        AssetAmount[] calldata inAssets,
        bytes calldata payload
    )
        external
        payable
        virtual
        override
        returns (AssetAmount[] memory outAssets)
    {
        uint24[] memory inAssetIds = new uint24[](inAssets.length);
        uint256[] memory inValues = new uint256[](inAssets.length);
        for (uint256 i; i < inAssets.length; i++) {
            inAssetIds[i] = inAssets[i].assetId;
            inValues[i] = inAssets[i].value;
        }
        uint24[] memory outAssetIds;
        uint256[] memory outValues;

        Payload memory decodedPayload = abi.decode(payload, (Payload));
        uint256 NCoins;
        // trying to access the third coin (index 2 of the coins array) to determine if it's a 2-coin or 3-coin pool
        try ICurvePool(decodedPayload.curvePool).coins(2) returns (address) {
            // In Curve's Vyper contract: coins(2) is accessing address[2] which will be present for 3-coin pool (length of address array is 3)
            NCoins = 3;
        } catch {
            // In Curve's Vyper contract: coins(2) is accessing address[2] which will be out of bounds for 2-coin pool (length of address array is 2), thus throwing an error which we catch here to set NCoins = 2
            NCoins = 2;
        }

        if (NCoins == 0) {
            revert InvalidCoinCount(NCoins);
        }

        if (decodedPayload.action == ACTION_SUPPLY) {
            _supplyChecksAndApprove(
                ICurvePool(decodedPayload.curvePool),
                NCoins,
                inAssetIds,
                inValues,
                decodedPayload.slippageBps
            );

            outAssetIds = new uint24[](1);
            outValues = new uint256[](1);

            (outAssetIds[0], outValues[0]) = _supply(
                ICurvePool(decodedPayload.curvePool),
                NCoins,
                inValues,
                decodedPayload.slippageBps
            );
            outAssets = new AssetAmount[](outAssetIds.length);
            for (uint256 i; i < outAssetIds.length; i++) {
                outAssets[i] = AssetAmount(outAssetIds[i], outValues[i]);
            }
        } else if (decodedPayload.action == ACTION_WITHDRAW) {
            _withdrawChecksAndApprove(
                ICurvePool(decodedPayload.curvePool),
                NCoins,
                inAssetIds,
                inValues,
                decodedPayload
            );

            // common params and return types for both 2 & 3 coin pools
            if (decodedPayload.withdrawType == uint8(WithdrawType.SINGLE)) {
                if (
                    ICurvePool(decodedPayload.curvePool).coins(
                        decodedPayload.singleCoinIndex
                    ) == address(0)
                ) {
                    revert InvalidCoinIndex(decodedPayload.singleCoinIndex);
                }

                outValues = new uint256[](1);
                outAssetIds = new uint24[](1);

                outValues[0] = _withdrawLiquiditySingleCoin(
                    ICurvePool(decodedPayload.curvePool),
                    inValues[0],
                    decodedPayload.singleCoinIndex
                );

                outAssetIds[0] = getAsset(
                    ICurvePool(decodedPayload.curvePool).coins(
                        decodedPayload.singleCoinIndex
                    )
                ).id;

                outAssets = new AssetAmount[](outAssetIds.length);
                for (uint256 i; i < outAssetIds.length; i++) {
                    outAssets[i] = AssetAmount(outAssetIds[i], outValues[i]);
                }
                return outAssets;
            }

            if (NCoins == 2) {
                if (
                    decodedPayload.withdrawType == uint8(WithdrawType.BALANCED)
                ) {
                    uint256 halfValue = inValues[0] / 2;
                    uint256 minAmtTokenA = _calcWithdrawOneCoin(
                        ICurvePool(decodedPayload.curvePool),
                        halfValue,
                        0
                    );

                    uint256 minAmtTokenB = _calcWithdrawOneCoin(
                        ICurvePool(decodedPayload.curvePool),
                        halfValue,
                        1
                    );

                    // deducting acceptable slippage
                    minAmtTokenA =
                        minAmtTokenA -
                        (minAmtTokenA * decodedPayload.slippageBps) /
                        BPS_PRECISION;
                    minAmtTokenB =
                        minAmtTokenB -
                        (minAmtTokenB * decodedPayload.slippageBps) /
                        BPS_PRECISION;

                    outValues = new uint256[](2);
                    outAssetIds = new uint24[](2);

                    outValues = _withdrawLiquidityBalanced2CoinPool(
                        ICurvePool(decodedPayload.curvePool),
                        inValues[0],
                        [minAmtTokenA, minAmtTokenB]
                    );
                }

                if (
                    decodedPayload.withdrawType ==
                    uint8(WithdrawType.IMBALANCED)
                ) {
                    _withdrawLiquidityImbalance2CoinPool(
                        ICurvePool(decodedPayload.curvePool),
                        [
                            decodedPayload.underlyingTokenAmts[0],
                            decodedPayload.underlyingTokenAmts[1]
                        ],
                        inValues[0]
                    );

                    outValues = new uint256[](2);
                    outAssetIds = new uint24[](2);

                    outValues[0] = decodedPayload.underlyingTokenAmts[0];
                    outValues[1] = decodedPayload.underlyingTokenAmts[0];
                }
            }

            if (NCoins == 3) {
                if (
                    decodedPayload.withdrawType == uint8(WithdrawType.BALANCED)
                ) {
                    uint256 thirdValue = inValues[0] / 3;
                    uint256 minAmtTokenA = _calcWithdrawOneCoin(
                        ICurvePool(decodedPayload.curvePool),
                        thirdValue,
                        0
                    );

                    uint256 minAmtTokenB = _calcWithdrawOneCoin(
                        ICurvePool(decodedPayload.curvePool),
                        thirdValue,
                        1
                    );

                    uint256 minAmtTokenC = _calcWithdrawOneCoin(
                        ICurvePool(decodedPayload.curvePool),
                        thirdValue,
                        2
                    );

                    // deducting acceptable slippage
                    minAmtTokenA =
                        minAmtTokenA -
                        (minAmtTokenA * decodedPayload.slippageBps) /
                        BPS_PRECISION;
                    minAmtTokenB =
                        minAmtTokenB -
                        (minAmtTokenB * decodedPayload.slippageBps) /
                        BPS_PRECISION;
                    minAmtTokenC =
                        minAmtTokenC -
                        (minAmtTokenC * decodedPayload.slippageBps) /
                        BPS_PRECISION;

                    outValues = new uint256[](3);
                    outAssetIds = new uint24[](3);

                    outValues = _withdrawLiquidityBalanced3CoinPool(
                        ICurvePool(decodedPayload.curvePool),
                        inValues[0],
                        [minAmtTokenA, minAmtTokenB, minAmtTokenC]
                    );
                }

                if (
                    decodedPayload.withdrawType ==
                    uint8(WithdrawType.IMBALANCED)
                ) {
                    _withdrawLiquidityImbalance3CoinPool(
                        ICurvePool(decodedPayload.curvePool),
                        [
                            decodedPayload.underlyingTokenAmts[0],
                            decodedPayload.underlyingTokenAmts[1],
                            decodedPayload.underlyingTokenAmts[2]
                        ],
                        inValues[0]
                    );

                    outValues = new uint256[](3);
                    outAssetIds = new uint24[](3);

                    outValues[0] = decodedPayload.underlyingTokenAmts[0];
                    outValues[1] = decodedPayload.underlyingTokenAmts[1];
                    outValues[2] = decodedPayload.underlyingTokenAmts[2];
                }
            }

            // preparing the outAssetIds arr
            for (uint256 i; i < NCoins; i++) {
                outAssetIds[i] = getAsset(
                    ICurvePool(decodedPayload.curvePool).coins(i)
                ).id;
            }

            outAssets = new AssetAmount[](outAssetIds.length);
            for (uint256 i; i < outAssetIds.length; i++) {
                outAssets[i] = AssetAmount(outAssetIds[i], outValues[i]);
            }
            return outAssets;
        } else {
            revert InvalidAction();
        }
    }

    function _supply(
        ICurvePool curve,
        uint256 NCoins,
        uint256[] memory inValues,
        uint256 slippageBps
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        /// @dev creating different functions for different curve pools as the curvePool contract expects a static sized `amounts` array in it's `calc_token_amount(uint256[2],bool)`, etc func. signature. We cannot use dynamic array niether can we create the func. signature string dynamically using string manupulation for abi.encodeWithSignature("funcSign", params) as `abi.encodeWithSignature` expects a constant string at compile time.
        if (NCoins == 2) {
            uint256 expectedLPTokens = _calcLPTokens2CoinPool(
                curve,
                inValues,
                true
            );

            // deducting acceptable slippage
            uint256 minLPTokens = expectedLPTokens -
                ((expectedLPTokens * slippageBps) / BPS_PRECISION);

            outAssetValue = _addLiquidity2CoinPool(
                curve,
                inValues,
                minLPTokens,
                address(this)
            );

            // LP tokens and Curve Pool share the same contract
            outAssetId = getAsset(address(curve)).id;
        } else if (NCoins == 3) {
            uint256 expectedLPTokens = _calcLPTokens3CoinPool(
                curve,
                inValues,
                true
            );

            // deducting acceptable slippage
            uint256 minLPTokens = expectedLPTokens -
                ((expectedLPTokens * slippageBps) / BPS_PRECISION);

            outAssetValue = _addLiquidity3CoinPool(
                curve,
                inValues,
                minLPTokens,
                address(this)
            );

            // LP tokens and Curve Pool share the same contract
            outAssetId = getAsset(address(curve)).id;
        } else {
            revert InvalidCoinCount(NCoins);
        }
    }

    /////////////////////////////
    ////// Getter func. /////////
    /////////////////////////////
    /// @notice Returns the pool's underlying tokens info.
    /// @param pool The address of the curve pool.
    /// @return poolUnderlyingTokensInfo The pool's underlying tokens info struct
    function getPoolCoinsAndIndexes(
        address pool
    ) external view returns (PoolUnderlyingTokensInfo memory) {
        ICurvePool curve = ICurvePool(pool);
        uint8 NCoins = 0;
        bool success = true;

        PoolUnderlyingTokensInfo
            memory poolUnderlyingTokensInfo = PoolUnderlyingTokensInfo({
                coins: new address[](3),
                balances: new uint256[](3),
                assetIds: new uint24[](3),
                indexes: new uint8[](3)
            });

        // getting pool's each coin details
        do {
            try curve.coins(uint256(NCoins)) returns (address coinAddress) {
                poolUnderlyingTokensInfo.coins[NCoins] = coinAddress;
                poolUnderlyingTokensInfo.balances[NCoins] = curve.balances(
                    uint256(NCoins)
                );
                poolUnderlyingTokensInfo.assetIds[NCoins] = getAsset(
                    coinAddress
                ).id;
                poolUnderlyingTokensInfo.indexes[NCoins] = NCoins;

                NCoins++;
            } catch {
                success = false;
            }
        } while (success);

        return poolUnderlyingTokensInfo;
    }

    /// @notice Returns the no. of LP tokens that will be minted or burnt for a given amount of underlying tokens being deposited or withdrawn.
    function getLPTokenCount(
        address pool,
        uint256[] calldata underlyingTokenAmts,
        bool isDeposit
    ) external view returns (uint256) {
        uint256 NCoins;
        // trying to access the third coin (index 2 of the coins array) to determine if it's a 2-coin or 3-coin pool
        try ICurvePool(pool).coins(2) returns (address) {
            // In Curve's Vyper contract: coins(2) is accessing address[2] which will be present for 3-coin pool (length of address array is 3)
            NCoins = 3;
        } catch {
            // In Curve's Vyper contract: coins(2) is accessing address[2] which will be out of bounds for 2-coin pool (length of address array is 2), thus throwing an error which we catch here to set NCoins = 2
            NCoins = 2;
        }
        if (underlyingTokenAmts.length != NCoins) {
            revert InvalidUnderlyingTokenAmountLength(
                underlyingTokenAmts.length,
                NCoins
            );
        }

        if (NCoins == 2) {
            return
                _calcLPTokens2CoinPool(
                    ICurvePool(pool),
                    underlyingTokenAmts,
                    isDeposit
                );
        }

        if (NCoins == 3) {
            return
                _calcLPTokens3CoinPool(
                    ICurvePool(pool),
                    underlyingTokenAmts,
                    isDeposit
                );
        }

        revert InvalidCoinCount(NCoins);
    }

    function totalLPTokenSupply(address pool) external view returns (uint256) {
        return ICurvePool(pool).totalSupply();
    }

    /////////////////////////////
    /// Internal func. /////////
    /////////////////////////////

    function _supplyChecksAndApprove(
        ICurvePool curve,
        uint256 NCoins,
        uint24[] memory inAssetIds,
        uint256[] memory inValues,
        uint256 slippageBps
    ) internal {
        if (inAssetIds.length != NCoins || inValues.length != NCoins) {
            revert InvalidInputAssetLength(
                uint8(inAssetIds.length),
                uint8(NCoins)
            );
        }

        for (uint256 i; i < inAssetIds.length; i++) {
            Asset memory inAsset = getAsset(inAssetIds[i]);
            bool supported = false;

            for (uint256 j; j < NCoins; j++) {
                if (inAsset.assetAddress == curve.coins(j)) {
                    supported = true;
                    break;
                }
            }

            if (!supported) {
                revert AssetNotSupportedByPool(inAsset.assetAddress, curve);
            }

            if (slippageBps > BPS_PRECISION) {
                revert InvalidSlippageBps(slippageBps, BPS_PRECISION);
            }

            IERC20(inAsset.assetAddress).forceApprove(
                address(curve),
                inValues[i]
            );
        }

        // reverting if ALL inValues are zero.
        // Will NOT revert if a single value is zero.
        if (NCoins == 2) {
            if (inValues[0] == 0 && inValues[1] == 0) {
                revert ZeroValue();
            }
        }

        if (NCoins == 3) {
            if (inValues[0] == 0 && inValues[1] == 0 && inValues[2] == 0) {
                revert ZeroValue();
            }
        }
    }

    function _withdrawChecksAndApprove(
        ICurvePool curve,
        uint256 NCoins,
        uint24[] memory inAssetIds,
        uint256[] memory inValues,
        Payload memory decodedPayload
    ) internal {
        if (inAssetIds.length != 1 || inValues.length != 1) {
            revert InvalidInputAssetLength(uint8(inAssetIds.length), 1);
        }

        Asset memory inAsset = getAsset(inAssetIds[0]);

        if (
            inAsset.assetAddress == address(0) ||
            inAsset.assetAddress != address(curve)
        ) {
            revert UnsupportedAsset(inAsset.id);
        }

        if (inValues[0] == 0) {
            revert ZeroValue();
        }

        if (decodedPayload.slippageBps > BPS_PRECISION) {
            revert InvalidSlippageBps(
                decodedPayload.slippageBps,
                BPS_PRECISION
            );
        }

        if (decodedPayload.withdrawType == uint8(WithdrawType.SINGLE)) {
            if (curve.coins(decodedPayload.singleCoinIndex) == address(0)) {
                revert InvalidCoinIndex(decodedPayload.singleCoinIndex);
            }
        }

        if (decodedPayload.withdrawType == uint8(WithdrawType.IMBALANCED)) {
            if (
                NCoins == 2 &&
                decodedPayload.underlyingTokenAmts[0] == 0 &&
                decodedPayload.underlyingTokenAmts[1] == 0
            ) {
                revert ZeroValue();
            }

            if (
                NCoins == 3 &&
                decodedPayload.underlyingTokenAmts[0] == 0 &&
                decodedPayload.underlyingTokenAmts[1] == 0 &&
                decodedPayload.underlyingTokenAmts[2] == 0
            ) {
                revert ZeroValue();
            }
        }

        IERC20(address(curve)).forceApprove(address(curve), inValues[0]);
    }

    // Two pool functions
    function _calcLPTokens2CoinPool(
        ICurvePool curve,
        uint256[] memory inValues,
        bool isDeposit
    ) internal view returns (uint256) {
        return curve.calc_token_amount([inValues[0], inValues[1]], isDeposit);
    }

    // Three pool functions
    function _calcLPTokens3CoinPool(
        ICurvePool curve,
        uint256[] memory inValues,
        bool isDeposit
    ) internal view returns (uint256) {
        // using static `amounts` array as expected by curePool contract
        // uint256[3] memory amounts = [inValues[0], inValues[1], inValues[2]];
        return
            curve.calc_token_amount(
                [inValues[0], inValues[1], inValues[2]],
                isDeposit
            );
    }

    function _addLiquidity2CoinPool(
        ICurvePool curve,
        uint256[] memory inValues,
        uint256 minLPTokens,
        address receiver
    ) internal returns (uint256) {
        // using static `amounts` array as expected by curePool contract
        // uint256[2] memory amounts = [inValues[0], inValues[1]];

        return
            curve.add_liquidity(
                [inValues[0], inValues[1]],
                minLPTokens,
                receiver
            );
    }

    function _addLiquidity3CoinPool(
        ICurvePool curve,
        uint256[] memory inValues,
        uint256 minLPTokens,
        address receiver
    ) internal returns (uint256) {
        // using static `amounts` array as expected by curePool contract
        // uint256[3] memory amounts = [inValues[0], inValues[1], inValues[2]];

        return
            curve.add_liquidity(
                [inValues[0], inValues[1], inValues[2]],
                minLPTokens,
                receiver
            );
    }

    function _calcWithdrawOneCoin(
        ICurvePool curve,
        uint256 burnAmount,
        int128 i
    ) internal view returns (uint256) {
        return curve.calc_withdraw_one_coin(burnAmount, i);
    }

    function _withdrawLiquidityBalanced2CoinPool(
        ICurvePool curve,
        uint256 withdrawLPTokens,
        uint256[2] memory minAmts
    ) internal returns (uint256[] memory) {
        // returning dynamically sized arr. as expected by outValues
        uint256[] memory coinsReceived = new uint256[](2);
        uint256[2] memory _coinsReceived = curve.remove_liquidity({
            _burn_amount: withdrawLPTokens,
            _min_amounts: minAmts,
            receiver: address(this)
        });

        coinsReceived[0] = _coinsReceived[0];
        coinsReceived[1] = _coinsReceived[1];
        return coinsReceived;
    }

    function _withdrawLiquidityBalanced3CoinPool(
        ICurvePool curve,
        uint256 withdrawLPTokens,
        uint256[3] memory minAmts
    ) internal returns (uint256[] memory) {
        // returning dynamically sized arr. as expected by outValues
        uint256[] memory coinsReceived = new uint256[](3);
        uint256[3] memory _coinsReceived = curve.remove_liquidity({
            _burn_amount: withdrawLPTokens,
            _min_amounts: minAmts,
            receiver: address(this)
        });

        coinsReceived[0] = _coinsReceived[0];
        coinsReceived[1] = _coinsReceived[1];
        coinsReceived[2] = _coinsReceived[2];
        return coinsReceived;
    }

    function _withdrawLiquiditySingleCoin(
        ICurvePool curve,
        uint256 withdrawLPTokens,
        uint8 singleCoinIndex
    ) internal returns (uint256) {
        return
            curve.remove_liquidity_one_coin(
                withdrawLPTokens,
                int8(singleCoinIndex),
                0,
                address(this)
            );
    }

    function _withdrawLiquidityImbalance2CoinPool(
        ICurvePool curve,
        uint256[2] memory _underlyingTokenAmts,
        uint256 withdrawLPTokens
    ) internal {
        curve.remove_liquidity_imbalance({
            _amounts: _underlyingTokenAmts,
            _max_burn_amount: withdrawLPTokens,
            _receiver: address(this)
        });
    }

    function _withdrawLiquidityImbalance3CoinPool(
        ICurvePool curve,
        uint256[3] memory _underlyingTokenAmts,
        uint256 withdrawLPTokens
    ) internal {
        curve.remove_liquidity_imbalance({
            _amounts: _underlyingTokenAmts,
            _max_burn_amount: withdrawLPTokens,
            _receiver: address(this)
        });
    }
}
