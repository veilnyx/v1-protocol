// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LabyrinthLimitOrderHook} from "./LabyrinthLimitOrderHook.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";

contract LabyrinthLimitOrderAdaptor is AdaptorBase {
    enum Action { PlaceOrder, CancelOrder, Redeem }

    struct LimitOrderParams {
        Action action;
        address inputToken;
        address outputToken;
        uint256 limitPrice;
        uint256 amount;
        bool zeroForOne;
        PoolKey key;
        int24 tickToSellAt;
    }

    LabyrinthLimitOrderHook public hook;

    constructor(address pool_, address _hook) AdaptorBase(pool_) {
        hook = LabyrinthLimitOrderHook(_hook);
    }

    // Helper function to calculate tick from price
    function _calculateTick(address inputToken, address outputToken, uint256 limitPrice) private view returns (int24) {
        uint8 inputDecimals = IERC20Metadata(inputToken).decimals();
        uint8 outputDecimals = IERC20Metadata(outputToken).decimals();
        // Normalize price to 18 decimals for sqrt math
        uint256 normPrice = limitPrice * (10**outputDecimals) / (10**inputDecimals);
        uint160 sqrtPriceX96 = uint160(FixedPointMathLib.sqrt(normPrice) * (2**96));
        return TickMath.getTickAtSqrtPrice(sqrtPriceX96);
    }

    /**
     * @dev Handles assets for placing, cancelling, or redeeming limit orders through the hook.
     * @param inAssetIds Asset IDs provided by Labyrinth (expecting single asset)
     * @param inValues Amounts provided by Labyrinth (expecting single value)
     * @param payload Encoded Uniswap V4 limit order action and parameters
     */
    function handleAssets(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata payload
    ) external payable override returns (uint24[] memory outAssetIds, uint256[] memory outValues) {
        require(inAssetIds.length == 1 && inValues.length == 1, "Single asset only");
        require(inValues[0] > 0, "Zero input");
        
        LimitOrderParams memory params;
        
        (params.action, params.inputToken, params.outputToken, params.limitPrice, params.amount, params.zeroForOne, params.key) = abi.decode(
            payload,
            (Action, address, address, uint256, uint256, bool, PoolKey)
        );
        
        // Calculate tick from price
        params.tickToSellAt = _calculateTick(params.inputToken, params.outputToken, params.limitPrice);

        address token = getAsset(inAssetIds[0]).assetAddress;
        IERC20 erc20 = IERC20(token);

        if (params.action == Action.PlaceOrder) {
            return _handlePlaceOrder(erc20, inValues[0], params);
        } else if (params.action == Action.CancelOrder) {
            return _handleCancelOrder(erc20, params);
        } else if (params.action == Action.Redeem) {
            return _handleRedeem(params);
        } else {
            revert("Invalid action");
        }
    }

    function _handlePlaceOrder(
        IERC20 erc20, 
        uint256 inputValue, 
        LimitOrderParams memory params
    ) private returns (uint24[] memory outAssetIds, uint256[] memory outValues) {
        require(inputValue >= params.amount, "Insufficient input");
        erc20.approve(address(hook), params.amount);
        hook.placeOrder(params.key, params.tickToSellAt, params.zeroForOne, params.amount);
        // No output asset for PlaceOrder
        outAssetIds = new uint24[](0);
        outValues = new uint256[](0);
    }

    function _handleCancelOrder(
        IERC20 erc20, 
        LimitOrderParams memory params
    ) private returns (uint24[] memory outAssetIds, uint256[] memory outValues) {
        // Set allowance to 0 before cancelling
        erc20.approve(address(hook), 0);
        hook.cancelOrder(params.key, params.tickToSellAt, params.zeroForOne, params.amount);
        // Output is the input token refunded
        (address outToken, uint256 outValue) = hook.getOutput(params.key, params.tickToSellAt, params.zeroForOne);
        uint24 outAssetId = getAsset(outToken).id;
        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);
        outAssetIds[0] = outAssetId;
        outValues[0] = outValue;
    }

    function _handleRedeem(
        LimitOrderParams memory params
    ) private returns (uint24[] memory outAssetIds, uint256[] memory outValues) {
        hook.redeem(params.key, params.tickToSellAt, params.zeroForOne, params.amount);
        // Output is the proceeds of the executed order
        (address outToken, uint256 outValue) = hook.getOutput(params.key, params.tickToSellAt, params.zeroForOne);
        uint24 outAssetId = getAsset(outToken).id;
        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);
        outAssetIds[0] = outAssetId;
        outValues[0] = outValue;
    }
}