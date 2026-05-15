// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {SwapDescription, IOneInch, IAggregationExecutor} from "./IOneInch.sol";
import {console} from "forge-std/Test.sol";

error OneInchSwapFailed();

contract OneInchAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    address constant oneInchRouter = 0x111111125421cA6dc452d289314280a0f8842A65;

    constructor(address pool_) AdaptorBase(pool_) {}

    /// @dev 1Inch swap router expects the calldata to be acquired from the 1Inch API. The calldata is then passed to the 1Inch router to execute the swap. Decoding is not required.
    /// @param inAssetIds Array of asset IDs to be swapped
    /// @param inValues Array of asset values to be swapped
    /// @param payload Calldata for 1Inch swap with the function signature (first 4 bytes) trimmed
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
        if (inAssetIds.length != 1 || inValues.length != 1) {
            revert InvalidInputAssetLength(uint8(inAssetIds.length), 1);
        }

        address inAsset = getAsset(inAssetIds[0]).assetAddress;

        if (inValues[0] == 0) {
            revert ZeroValue();
        }

        if (inAsset == address(0)) {
            revert ZeroValue();
        }

        // decoding 1Inch `calldata` to make interface call (avoiding low-level call)
        (
            address executor,
            SwapDescription memory swapDesc,
            bytes memory data
        ) = abi.decode(payload, (address, SwapDescription, bytes));

        IERC20(inAsset).forceApprove(oneInchRouter, inValues[0]);
        (uint256 dstTokenReturnAmt, uint256 srcTokenSpentAmt) = IOneInch(
            oneInchRouter
        ).swap(IAggregationExecutor(executor), swapDesc, data);

        uint256 srcTokenReturnAmt = inValues[0] - srcTokenSpentAmt;

        // checking if any input token amount is returned which was not swapped. Needs to be returned.
        if (srcTokenReturnAmt > 0) {
            outValues = new uint256[](2);
            outValues[0] = srcTokenReturnAmt;
            outValues[1] = dstTokenReturnAmt;

            outAssetIds = new uint24[](2);
            outAssetIds[0] = inAssetIds[0];
            outAssetIds[1] = getAssetId(address(swapDesc.dstToken));
        } else {
            outValues = new uint256[](1);
            outValues[0] = dstTokenReturnAmt;

            outAssetIds = new uint24[](1);
            outAssetIds[0] = getAssetId(address(swapDesc.dstToken));
        }
    }
}
