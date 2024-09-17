// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/Asset.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {ICurvePool} from "./ICurvePool.sol";
import {console2} from "forge-std/console2.sol";

struct Payload {
    address curvePool;
    uint8 action;
    uint8 withdrawType;
    uint8 singleCoinIndex;
    uint256[] underlyingTokenAmts;
}

contract CurveNGAdaptor is AdaptorBase, Ownable {
    using SafeERC20 for IERC20;

    error InsufficientBalance();
    error InvalidInput();
    error AssetNotSupportedByPool(address asset, address curvePool);

    uint8 constant ACTION_SUPPLY = 0;
    uint8 constant ACTION_WITHDRAW = 1;

    enum WithdrawType {
        BALANCED,
        SINGLE,
        IMBALANCED
    }

    constructor(address pool_) AdaptorBase(pool_) Ownable(msg.sender) {}

    function handleAssets(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata payload
    )
        external
        payable
        virtual
        override
        returns (uint24[] memory outAssetIds, uint256[] memory outValues)
    {
        Payload memory decodedPayload = abi.decode(payload, (Payload));

        uint256 NCoins = 0;
        bool success = true;
        do {
            try ICurvePool(decodedPayload.curvePool).coins(NCoins) returns (
                address
            ) {
                NCoins++;
            } catch {
                success = false;
            }
        } while (success);

        if (NCoins == 0) {
            revert InvalidInput();
        }

        if (decodedPayload.action == ACTION_SUPPLY) {
            _supplyChecksAndApprove(
                ICurvePool(decodedPayload.curvePool),
                NCoins,
                inAssetIds,
                inValues
            );

            outAssetIds = new uint24[](1);
            outValues = new uint256[](1);

            (outAssetIds[0], outValues[0]) = _supply(
                ICurvePool(decodedPayload.curvePool),
                NCoins,
                inValues
            );
        } else if (decodedPayload.action == ACTION_WITHDRAW) {
            _withdrawChecksAndApprove(
                ICurvePool(decodedPayload.curvePool),
                inAssetIds[0],
                inValues[0]
            );

            if (NCoins == 2) {
                if (
                    decodedPayload.withdrawType == uint8(WithdrawType.BALANCED)
                ) {
                    /// @todo This implementation results in `revert: Withdrawal resulted in fewer coins than expected`. Need to investigate.
                    /// @notice hardcoding the minAmt of both tokens to 0 for now.
                    /**
                    uint256 minAmtTokenA = _calcWithdrawOneCoin(inValues[0] / 2, 0);
                    console2.log("minAmtTokenA", minAmtTokenA);
                    uint256 minAmtTokenB = _calcWithdrawOneCoin(inValues[0] / 2, 1);
                    console2.log("minAmtTokenB", minAmtTokenB);

                    // allow 0.5% slippage
                    minAmtTokenA = minAmtTokenA - ((minAmtTokenA * 5) / 1000);
                    minAmtTokenB = minAmtTokenB - ((minAmtTokenB * 5) / 1000);
                    */
                    outValues = new uint256[](2);
                    outAssetIds = new uint24[](2);

                    outValues = _withdrawLiquidityBalanced2CoinPool(
                        ICurvePool(decodedPayload.curvePool),
                        inValues[0]
                    );

                    // preparing the outAssetIds arr
                    for (uint256 i; i < NCoins; i++) {
                        outAssetIds[i] = getAsset(
                            ICurvePool(decodedPayload.curvePool).coins(i)
                        ).id;
                    }
                }

                if (decodedPayload.withdrawType == uint8(WithdrawType.SINGLE)) {
                    if (
                        ICurvePool(decodedPayload.curvePool).coins(
                            decodedPayload.singleCoinIndex
                        ) == address(0)
                    ) {
                        revert InvalidInput();
                    }

                    outValues = new uint256[](1);
                    outAssetIds = new uint24[](1);

                    outValues[0] = _withdrawLiquiditySingle2CoinPool(
                        ICurvePool(decodedPayload.curvePool),
                        inValues[0],
                        decodedPayload.singleCoinIndex
                    );
                    console2.log("Single coins received", outValues[0]);

                    outAssetIds[0] = getAsset(
                        ICurvePool(decodedPayload.curvePool).coins(
                            decodedPayload.singleCoinIndex
                        )
                    ).id;
                }

                if (
                    decodedPayload.withdrawType ==
                    uint8(WithdrawType.IMBALANCED)
                ) {
                    if (
                        decodedPayload.underlyingTokenAmts[0] == 0 ||
                        decodedPayload.underlyingTokenAmts[1] == 0
                    ) {
                        revert InvalidInput();
                    }
                    // creating a static array to send to the curve pool
                    // uint256[2] memory _underlyingTokenAmts;
                    // _underlyingTokenAmts[0] = decodedPayload.underlyingTokenAmts[0];
                    // _underlyingTokenAmts[1] = decodedPayload.underlyingTokenAmts[1];

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

                    // preparing the outAssetIds arr
                    for (uint256 i; i < NCoins; i++) {
                        outAssetIds[i] = getAsset(
                            ICurvePool(decodedPayload.curvePool).coins(i)
                        ).id;
                    }
                }
            }

            /// @dev Getting stack too deep.
            // (outAssetIds, outValues) = _withdraw(
            //     curve,
            //     NCoins,
            //     inAssetIds[0],
            //     uint256(inValues[0]),
            //     decodedPayload.withdrawType,
            //     decodedPayload.singleCoinIndex,
            //     singleCoinAddress
            // );
        } else {
            revert InvalidAction();
        }
    }

    function _supply(
        ICurvePool curve,
        uint256 NCoins,
        uint256[] memory inValues
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        /// @dev creating different functions for different curve pools as the curvePool contract expects a static sized `amounts` array in it's `calc_token_amount(uint256[2],bool)`, etc func. signature. We cannot use dynamic array niether can we create the func. signature string dynamically using string manupulation for abi.encodeWithSignature("funcSign", params) as `abi.encodeWithSignature` expects a constant string at compile time.
        if (NCoins == 2) {
            uint256 expectedLPTokens = _calcLPTokens2CoinPool(
                curve,
                inValues,
                true
            );

            // 0.5% slippage
            uint256 minLPTokens = expectedLPTokens -
                ((expectedLPTokens * 5) / 1000);

            outAssetValue = _addLiquidity2CoinPool(
                curve,
                inValues,
                minLPTokens,
                address(this)
            );

            // LP tokens and Curve Pool share the same contract
            outAssetId = getAsset(address(curve)).id;
        }

        if (NCoins == 3) {
            uint256 expectedLPTokens = _calcLPTokens3CoinPool(
                curve,
                inValues,
                true
            );

            // 0.5% slippage
            uint256 minLPTokens = expectedLPTokens -
                ((expectedLPTokens * 5) / 1000);

            outAssetValue = _addLiquidity3CoinPool(
                curve,
                inValues,
                minLPTokens,
                address(this)
            );

            // LP tokens and Curve Pool share the same contract
            outAssetId = getAsset(address(curve)).id;
        }
    }

    function _supplyChecksAndApprove(
        ICurvePool curve,
        uint256 NCoins,
        uint24[] memory inAssetIds,
        uint256[] memory inValues
    ) internal {
        for (uint256 i; i < inAssetIds.length; i++) {
            Asset memory inAsset = getAsset(inAssetIds[i]);
            bool supported = false;

            for (uint256 j; j < NCoins; j++) {
                if (inAsset.assetAddress == curve.coins(j)) {
                    supported = true;
                }
            }

            if (!supported) revert InvalidInput();

            if (inValues[i] == 0) {
                revert ZeroValue();
            }

            if (
                IERC20(inAsset.assetAddress).balanceOf(address(this)) <
                inValues[i]
            ) {
                revert InsufficientBalance();
            }

            if (NCoins != inAssetIds.length || NCoins != inValues.length) {
                revert InvalidInput();
            }

            IERC20(inAsset.assetAddress).forceApprove(
                address(curve),
                inValues[i]
            );
        }
    }

    function _withdrawChecksAndApprove(
        ICurvePool curve,
        uint24 inAssetId,
        uint256 inValue
    ) internal {
        Asset memory inAsset = getAsset(inAssetId);

        if (
            inAsset.assetAddress == address(0) ||
            inAsset.assetAddress != address(curve)
        ) {
            revert UnsupportedAsset(inAsset.id);
        }

        if (inValue == 0) {
            revert ZeroValue();
        }

        if (IERC20(inAsset.assetAddress).balanceOf(address(this)) < inValue) {
            revert InsufficientBalance();
        }

        IERC20(address(curve)).forceApprove(address(curve), inValue);
    }

    /////////////////////////////
    ////// Getter func. /////////
    /////////////////////////////
    function getPoolCoinsAndIndexes(
        address pool
    )
        external
        view
        returns (
            address[] memory coins,
            uint256[] memory balances,
            uint24[] memory assetIds,
            uint8[] memory indexes
        )
    {
        ICurvePool curve = ICurvePool(pool);
        uint8 NCoins = 0;
        bool success = true;
        coins = new address[](3);
        balances = new uint256[](3);
        assetIds = new uint24[](3);
        indexes = new uint8[](3);

        do {
            try curve.coins(uint256(NCoins)) returns (address coinAddress) {
                coins[NCoins] = coinAddress;
                balances[NCoins] = curve.balances(uint256(NCoins));
                assetIds[NCoins] = getAsset(coinAddress).id;
                indexes[NCoins] = NCoins;

                NCoins++;
            } catch {
                success = false;
            }
        } while (success);
    }

    /////////////////////////////
    /// Internal func. /////////
    /////////////////////////////

    // Two pool functions
    function _calcLPTokens2CoinPool(
        ICurvePool curve,
        uint256[] memory inValues,
        bool isDeposit
    ) internal view returns (uint256) {
        // using static `amounts` array as expected by curePool contract
        // uint256[2] memory amounts = [inValues[0], inValues[1]];
        return curve.calc_token_amount([inValues[0], inValues[1]], isDeposit);
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

    function _calcWithdrawOneCoin(
        ICurvePool curve,
        uint256 burnAmount,
        int128 i
    ) internal view returns (uint256) {
        return curve.calc_withdraw_one_coin(burnAmount, i);
    }

    function _withdrawLiquidityBalanced2CoinPool(
        ICurvePool curve,
        uint256 withdrawLPTokens
    ) internal returns (uint256[] memory) {
        uint256[] memory coinsReceived = new uint256[](2);
        uint256[2] memory _coinsReceived = curve.remove_liquidity({
            _burn_amount: withdrawLPTokens,
            _min_amounts: [uint256(0), uint256(0)],
            receiver: address(this)
        });

        coinsReceived[0] = _coinsReceived[0];
        coinsReceived[1] = _coinsReceived[1];
        return coinsReceived;
    }

    function _withdrawLiquiditySingle2CoinPool(
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
        console2.log("Imbal withdraw lp tokens burnt successfully");
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
}
