// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {SwapDescription, IOneInch, IAggregationExecutor} from "./IOneInch.sol";
import {AssetAmount} from "../../interfaces/IAdaptor.sol";
import {console} from "forge-std/Test.sol";

error OneInchSwapFailed();

contract OneInchAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    address public immutable oneInchRouter;

    constructor(address pool_, address oneInchRouter_) AdaptorBase(pool_) {
        oneInchRouter = oneInchRouter_;
    }

    /// @dev 1Inch swap router expects the calldata to be acquired from the 1Inch API. The calldata is then passed to the 1Inch router to execute the swap. Decoding is not required.
    /// @param inAssets Array of asset amounts to be swapped
    /// @param payload Calldata for 1Inch swap with the function signature (first 4 bytes) trimmed
    function handleAssets(
        AssetAmount[] calldata inAssets,
        bytes calldata payload
    ) external payable override returns (AssetAmount[] memory outAssets) {
        if (inAssets.length != 1) {
            revert InvalidInputAssetLength(uint8(inAssets.length), 1);
        }

        address inAsset = getAsset(inAssets[0].assetId).assetAddress;

        if (inAssets[0].value == 0) {
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

        IERC20(inAsset).forceApprove(oneInchRouter, inAssets[0].value);
        (uint256 dstTokenReturnAmt, uint256 srcTokenSpentAmt) = IOneInch(
            oneInchRouter
        ).swap(IAggregationExecutor(executor), swapDesc, data);

        uint256 srcTokenReturnAmt = inAssets[0].value - srcTokenSpentAmt;

        // checking if any input token amount is returned which was not swapped. Needs to be returned.
        if (srcTokenReturnAmt > 0) {
            outAssets = new AssetAmount[](2);
            outAssets[0] = AssetAmount(inAssets[0].assetId, srcTokenReturnAmt);
            outAssets[1] = AssetAmount(
                getAssetId(address(swapDesc.dstToken)),
                dstTokenReturnAmt
            );
        } else {
            outAssets = new AssetAmount[](1);
            outAssets[0] = AssetAmount(
                getAssetId(address(swapDesc.dstToken)),
                dstTokenReturnAmt
            );
        }
    }
}
