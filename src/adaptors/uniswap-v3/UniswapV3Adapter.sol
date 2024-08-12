// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdaptorBase} from "src/base/AdaptorBase.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ISwapRouter02} from "./ISwapRouter02.sol";
import {console} from "forge-std/Test.sol";

contract UniswapV3Adapter is AdaptorBase {
    // Errors //
    error UnsupportedAsset(uint24 assetId);
    error MultiAssetSwap();
    error ZeroValues();

    ISwapRouter02 public immutable swapRouter02;
    uint24 public constant feeTier = 3000;

    constructor(address swapRouter02_, address pool_) AdaptorBase(pool_) {
        swapRouter02 = ISwapRouter02(swapRouter02_); // Uniswap V3 Swap router
    }

    /// @dev Will be called by the zkFi AdaptorHandler.sol to execute the swap.
    function handleAssets(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata payload
    )
        external
        payable
        override
        returns (uint24[] memory outAssetIds, uint256[] memory outValues)
    {
        uint256 inValue;
        // Checks
        if (inAssetIds.length != 1 || inValues.length != 1) {
            revert MultiAssetSwap();
        }

        if (inValues[0] == 0) {
            revert ZeroValues();
        } else {
            inValue = inValues[0];
            console.log("UniswapV3Adp:: inValue to swap:", inValue);
        }

        Asset memory inAsset = getAsset(inAssetIds[0]);
        if (!inAsset.isSupported) {
            revert UnsupportedAsset(inAssetIds[0]);
        }

        // decoding payload
        (uint24 outAssetId, address beneficiary, uint256 minOut) = abi.decode(
            payload,
            (uint24, address, uint256)
        );

        Asset memory outAsset = getAsset(outAssetId);
        if (!outAsset.isSupported) {
            revert UnsupportedAsset(outAssetId);
        }

        if (beneficiary == address(0)) {
            // means the out tokens will go to the ZKFI AdaptorHandler and have to be processed to the pool
            beneficiary = address(this); // AdaptorHandler.sol
        }

        // Executing swap using UniswapV3
        uint256 tokenOutAmount = swapExactInputSingle({
            tokenIn: inAsset.assetAddress,
            tokenInAmt: inValue,
            tokenOut: outAsset.assetAddress,
            minOut: minOut,
            beneficiary: beneficiary
        });

        // initialising out arrays
        if (beneficiary == address(this)) {
            outAssetIds = new uint24[](1);
            outValues = new uint256[](1);

            outAssetIds[0] = outAssetId;
            outValues[0] = tokenOutAmount;
        } else {
            outAssetIds = new uint24[](0);
            outValues = new uint256[](0);
        }
    }

    /// @param tokenIn The address of the token to be swapped
    /// @param tokenInAmt The amount of `tokenIn` tokens to swap
    /// @param tokenOut The address of the output token
    /// @param minOut The minimum amount of output token the user expects to get back. This is used for slippage protection
    /// @param beneficiary The address which will receive the output tokens. This will be the zkFi Convertor.sol contract.
    function swapExactInputSingle(
        address tokenIn,
        uint256 tokenInAmt,
        address tokenOut,
        uint256 minOut,
        address beneficiary
    ) public returns (uint256 amountOut) {
        // Uniswap adaptor to approve Uniswap's Swap Router contract the inTokens received.
        SafeERC20.forceApprove(
            IERC20(tokenIn),
            address(swapRouter02),
            tokenInAmt
        );

        // Create the params that will be used to execute the swap
        /// @param sqrtPriceLimitX96 This is the sqrt of potential value decrease of outAsset relative to inAsset (uint160), that the trader is willing to ignore for the swap. We will be deactivating this protective measure for the MVP. We will only be deploying the slippage protection using `amountOutMinimum`
        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: feeTier,
                recipient: beneficiary,
                amountIn: tokenInAmt,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: uint160(0)
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter02.exactInputSingle(params);
    }
}
