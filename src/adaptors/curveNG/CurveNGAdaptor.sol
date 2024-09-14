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

contract CurveNGAdaptor is AdaptorBase, Ownable {
    using SafeERC20 for IERC20;

    error InsufficientBalance();
    error InvalidInput();
    error AssetNotSupportedByPool(address asset, address curvePool);

    ICurvePool public curve;
    uint8 constant ACTION_SUPPLY = 0;
    uint8 constant ACTION_WITHDRAW = 1;

    enum WithdrawType {
        BALANCED,
        IMBALANCED
        SINGLE,
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
        (address curvePool, uint8 action) = abi.decode(
            payload,
            (address, uint8)
        );
        curve = ICurvePool(curvePool);
        uint256 NCoins = 0;
        bool success = true;

        do {
            try curve.coins(NCoins) returns (address) {
                NCoins++;
            } catch {
                success = false;
            }
        } while (success);

        if (NCoins == 0) {
            revert InvalidInput();
        }

        if (action == ACTION_SUPPLY) {
            outAssetIds = new uint24[](1);
            outValues = new uint256[](1);

            (outAssetIds[0], outValues[0]) = _supply(
                NCoins,
                inAssetIds,
                inValues
            );
        } else if (action == ACTION_WITHDRAW) {
            outAssetIds = new uint24[](NCoins);
            outValues = new uint256[](NCoins);

            (outAssetIds, outValues) = _withdraw(
                NCoins,
                inAssetIds[0],
                uint256(inValues[0])
            );
        } else {
            revert InvalidAction();
        }
    }

    function _supply(
        uint256 NCoins,
        uint24[] memory inAssetIds,
        uint256[] memory inValues
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        if (NCoins != inAssetIds.length || NCoins != inValues.length) {
            revert InvalidInput();
        }

        // Check if the input assets are supported by the curve pool
        for (uint256 i; i < inAssetIds.length; i++) {
            address inAssetAddr = getAsset(inAssetIds[i]).assetAddress;
            bool supported = false;

            for (uint256 j; j < NCoins; j++) {
                if (inAssetAddr == curve.coins(j)) {
                    supported = true;
                }
            }

            if (!supported) revert InvalidInput();

            if (inValues[i] == 0) {
                revert ZeroValue();
            }

            Asset memory inAsset = getAsset(inAssetIds[i]);
            address inputAsset = inAsset.assetAddress;
            uint256 lendValue = inValues[i];

            uint256 assetBal = IERC20(inputAsset).balanceOf(address(this));
            if (assetBal < lendValue) {
                revert InsufficientBalance();
            }
            IERC20(inputAsset).forceApprove(address(curve), lendValue);
        }

        /// @dev creating different functions for different curve pools as the curvePool contract expects a static sized `amounts` array in it's `calc_token_amount(uint256[2],bool)`, etc func. signature. We cannot use dynamic array niether can we create the func. signature string dynamically using string manupulation for abi.encodeWithSignature("funcSign", params) as `abi.encodeWithSignature` expects a constant string at compile time.
        if (NCoins == 2) {
            uint256 expectedLPTokens = _calcLPTokens2CoinPool(inValues, true);

            // 0.5% slippage
            uint256 minLPTokens = expectedLPTokens -
                ((expectedLPTokens * 5) / 1000);

            uint256 lpTokens = _addLiquidity2CoinPool(
                inValues,
                minLPTokens,
                address(this)
            );

            // LP tokens and Curve Pool share the same contract
            outAssetId = getAsset(address(curve)).id;
            outAssetValue = lpTokens;
        }

        if (NCoins == 3) {
            uint256 expectedLPTokens = _calcLPTokens3CoinPool(inValues, true);

            // 0.5% slippage
            uint256 minLPTokens = expectedLPTokens -
                ((expectedLPTokens * 5) / 1000);

            uint256 lpTokens = _addLiquidity3CoinPool(
                inValues,
                minLPTokens,
                address(this)
            );

            // LP tokens and Curve Pool share the same contract
            outAssetId = getAsset(address(curve)).id;
            outAssetValue = lpTokens;
        }
    }

    function _withdraw(
        uint256 NCoins,
        uint24 inAssetId,
        uint256 inValue
    )
        internal
        returns (uint24[] memory outAssetIds, uint256[] memory outAssetValues)
    {
        // Redeeming/Withdrawing
        Asset memory inAsset = getAsset(inAssetId);
        address lpToken = inAsset.assetAddress;

        if (lpToken == address(0)) {
            revert UnsupportedAsset(inAsset.id);
        }

        if (inValue == 0) {
            revert ZeroValue();
        }

        uint256 lpTokenBal = IERC20(lpToken).balanceOf(address(this));
        if (lpTokenBal < inValue) {
            revert InsufficientBalance();
        }

        IERC20(lpToken).forceApprove(address(curve), inValue);

        if (NCoins == 2) {
            /// @todo This implementation results in `revert: Withdrawal resulted in fewer coins than expected`. Need to investigate. 
            /// @notice hardcoding the minAmt of both tokens to 0 for now.
            /**
            uint256 minAmtTokenA = _calcWithdrawOneCoin(inValue / 2, 0);
            console2.log("minAmtTokenA", minAmtTokenA);
            uint256 minAmtTokenB = _calcWithdrawOneCoin(inValue / 2, 1);
            console2.log("minAmtTokenB", minAmtTokenB);

            // allow 0.5% slippage
            minAmtTokenA = minAmtTokenA - ((minAmtTokenA * 5) / 1000);
            minAmtTokenB = minAmtTokenB - ((minAmtTokenB * 5) / 1000);
             */
            uint256 minAmtTokenA = 0;
            uint256 minAmtTokenB = 0;
            
            uint256[2] memory coinsReceived = _withdrawLiquidity2CoinPool(
                inValue,
                minAmtTokenA,
                minAmtTokenB
            );
            console2.log("USDT received", coinsReceived[0]);
            console2.log("CRV received", coinsReceived[1]);
            outAssetValues = new uint256[](2);
            outAssetIds = new uint24[](2);

            outAssetValues[0] = coinsReceived[0];
            outAssetValues[1] = coinsReceived[1];
        }

        // preparing the outAssetIds arr
        for (uint256 i; i < NCoins; i++) {
            outAssetIds[i] = getAsset(curve.coins(i)).id;
        }
    }

    function _calcLPTokens2CoinPool(
        uint256[] memory inValues,
        bool isDeposit
    ) internal view returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[2] memory amounts = [inValues[0], inValues[1]];
        lpTokenAmount = curve.calc_token_amount(amounts, isDeposit);
    }

    function _addLiquidity2CoinPool(
        uint256[] memory inValues,
        uint256 minLPTokens,
        address receiver
    ) internal returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[2] memory amounts = [inValues[0], inValues[1]];

        lpTokenAmount = curve.add_liquidity(amounts, minLPTokens, receiver);
    }

    function _calcWithdrawOneCoin(
        uint256 burnAmount,
        int128 i
    ) internal view returns (uint256 coinAmount) {
        coinAmount = curve.calc_withdraw_one_coin(burnAmount, i);
    }

    function _withdrawLiquidity2CoinPool(
        uint256 inValue,
        uint256 minAmtTokenA,
        uint256 minAmtTokenB
    ) internal returns (uint256[2] memory coinsReceived) {
        uint256[2] memory minAmts = [minAmtTokenA, minAmtTokenB];

        uint256[2] memory received = curve.remove_liquidity({
            _burn_amount: inValue,
            _min_amounts: minAmts,
            receiver: address(this)
        });

        // returning a dynamic array
        coinsReceived[0] = received[0];
        coinsReceived[1] = received[1];
    }

    function _calcLPTokens3CoinPool(
        uint256[] memory inValues,
        bool isDeposit
    ) internal view returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[3] memory amounts = [inValues[0], inValues[1], inValues[2]];
        lpTokenAmount = curve.calc_token_amount(amounts, isDeposit);
    }

    function _addLiquidity3CoinPool(
        uint256[] memory inValues,
        uint256 minLPTokens,
        address receiver
    ) internal returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[3] memory amounts = [inValues[0], inValues[1], inValues[2]];

        lpTokenAmount = curve.add_liquidity(amounts, minLPTokens, receiver);
    }
}
