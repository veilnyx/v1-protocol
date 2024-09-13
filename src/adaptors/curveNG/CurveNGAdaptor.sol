// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/Asset.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {ICurvePool} from "./ICurvePool.sol";

contract CurveNGAdaptor is AdaptorBase, Ownable {
    using SafeERC20 for IERC20;

    error InsufficientBalance();
    error InvalidInput();
    error AssetNotSupportedByPool(address asset, address curvePool);

    ICurvePool public curve;
    /// @todo Support all coins of all pools supported
    /// @todo Support LP token of all pools supported. LP token and Curve curvePool share the same contract.

    uint8 constant ACTION_SUPPLY = 0;
    uint8 constant ACTION_WITHDRAW = 1;

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

        if (NCoins != inAssetIds.length) {
            revert InvalidInput();
        }

        for (uint256 i; i < inAssetIds.length; i++) {
            address inAssetAddr = getAsset(inAssetIds[i]).assetAddress;
            bool supported = false;

            for (uint256 j; j < NCoins; j++) {
                if (inAssetAddr == curve.coins(j)) {
                    supported = true;
                }
            }

            if (!supported) revert InvalidInput();
        }

        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);

        if (action == ACTION_SUPPLY) {
            (outAssetIds[0], outValues[0]) = _supply(
                NCoins,
                inAssetIds,
                inValues
            );
        }
        /**
        else if (action == ACTION_WITHDRAW) {
            (outAssetIds[0], outValues[0]) = _withdraw(
                inAssetIds[0],
                uint256(inValues[0])
            );
        } */
        else {
            revert InvalidAction();
        }
    }

    function _supply(
        uint256 NCoins,
        uint24[] memory inAssetIds,
        uint256[] memory inValues
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        for (uint256 i = 0; i < inAssetIds.length; i++) {
            Asset memory inAsset = getAsset(inAssetIds[i]);
            address inputAsset = inAsset.assetAddress;
            uint256 lendValue = inValues[i];

            if (lendValue == 0) {
                revert ZeroValue();
            }

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

    /**
    function _withdraw(
        uint24 inAssetId,
        uint256 inValue
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        // Redeeming/Withdrawing
        Asset memory inAsset = getAsset(inAssetId);

        // static aToken -> aToken -> underlying asset
        address staticAToken = inAsset.assetAddress;
        address aToken = IStaticAToken(staticAToken).aToken();
        address underlyingAsset = IAToken(aToken).UNDERLYING_ASSET_ADDRESS();

        if (aToken == address(0)) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 staticATokenBal = IERC20(staticAToken).balanceOf(address(this));
        if (staticATokenBal < inValue) {
            revert InsufficientBalance();
        }

        (, uint256 amountToWithdraw) = IStaticAToken(staticAToken).redeem({
            shares: staticATokenBal,
            receiver: address(this),
            owner: address(this),
            withdrawFromAave: false
        });

        IERC20(aToken).approve(address(aave), amountToWithdraw);
        uint256 underlyingAssetReceived = aave.withdraw({
            asset: underlyingAsset,
            amount: amountToWithdraw,
            to: address(this)
        });

        outAssetId = getAsset(underlyingAsset).id;
        outAssetValue = underlyingAssetReceived;
    }
     */


    function _calcLPTokens2CoinPool(
        uint256[] memory inValues,
        bool isDeposit
    ) internal view returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[2] memory amounts = [inValues[0], inValues[1]];
        (, bytes memory lpToken) = address(curve).staticcall(
            abi.encodeWithSignature(
                "calc_token_amount(uint256[2],bool)",
                amounts,
                isDeposit
            )
        );
        uint256 lpTokenAmount = abi.decode(lpToken, (uint256));
        return lpTokenAmount;
    }

    function _addLiquidity2CoinPool(
        uint256[] memory inValues,
        uint256 minLPTokens,
        address receiver
    ) internal returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[2] memory amounts = [inValues[0], inValues[1]];

        (, bytes memory lpToken) = address(curve).call(
            abi.encodeWithSignature(
                "add_liquidity(uint256[2],uint256,address)",
                amounts,
                minLPTokens,
                receiver
            )
        );
        uint256 lpTokenAmount = abi.decode(lpToken, (uint256));
        return lpTokenAmount;
    }

     function _calcLPTokens3CoinPool(
        uint256[] memory inValues,
        bool isDeposit
    ) internal view returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[3] memory amounts = [inValues[0], inValues[1], inValues[2]];
        (, bytes memory lpToken) = address(curve).staticcall(
            abi.encodeWithSignature(
                "calc_token_amount(uint256[3],bool)",
                amounts,
                isDeposit
            )
        );
        uint256 lpTokenAmount = abi.decode(lpToken, (uint256));
        return lpTokenAmount;
    }

    function _addLiquidity3CoinPool(
        uint256[] memory inValues,
        uint256 minLPTokens,
        address receiver
    ) internal returns (uint256 lpTokenAmount) {
        // using static `amounts` array as expected by curePool contract
        uint256[3] memory amounts = [inValues[0], inValues[1], inValues[2]];

        (, bytes memory lpToken) = address(curve).call(
            abi.encodeWithSignature(
                "add_liquidity(uint256[3],uint256,address)",
                amounts,
                minLPTokens,
                receiver
            )
        );
        uint256 lpTokenAmount = abi.decode(lpToken, (uint256));
        return lpTokenAmount;
    }
}
