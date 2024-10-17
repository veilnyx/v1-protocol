// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {console2} from "forge-std/console2.sol";
import {IOneInch, IAggregationExecutor, SwapDescription} from "./IOneInch.sol";

error OneInchSwapFailed();

contract OneInchAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    address constant oneInchRouter = 0x111111125421cA6dc452d289314280a0f8842A65;

    constructor(address pool_) AdaptorBase(pool_) {}

    /// @dev 1Inch swap router expects the calldata to be acquired from the 1Inch API. The calldata is then passed to the 1Inch router to execute the swap as `payload`. Decoding is not required.
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
        (
            address executor,
            SwapDescription memory swapDescription,
            bytes memory data
        ) = abi.decode(payload, (address, SwapDescription, bytes));

        console2.log("decoded calldata");
        console2.log("Executor:", executor);

        // address destinationToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        // bytes
        //     memory oneInchCalldata = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000004d47696e08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dc06d4e6c5";

        address inAsset = getAsset(inAssetIds[0]).assetAddress;

        if (inValues[0] == 0) {
            revert ZeroValue();
        }

        if (inAsset == address(0)) {
            revert ZeroValue();
        }

        IERC20(inAsset).forceApprove(oneInchRouter, inValues[0]);

        outValues = new uint256[](1);
        (uint256 returnAmount, uint256 spentAmount) = IOneInch(oneInchRouter)
            .swap(IAggregationExecutor(executor), swapDescription, data);

        console2.log("1Inch swap succeeded");

        console2.log("Returned amount:", returnAmount);
        console2.log("Spent amount:", spentAmount);
        outValues[0] = swapDescription.dstToken.balanceOf(address(this));
        outAssetIds = new uint24[](1);
        outAssetIds[0] = getAssetId(address(swapDescription.dstToken));
    }
}
