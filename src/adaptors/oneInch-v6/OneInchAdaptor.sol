// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";

error OneInchSwapFailed();

contract OneInchAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    address constant oneInchRouter = 0x111111125421cA6dc452d289314280a0f8842A65;

    constructor(address pool_) AdaptorBase(pool_) {}

    /// @dev 1Inch swap router expects the calldata to be acquired from the 1Inch API. The calldata is then passed to the 1Inch router to execute the swap. Decoding is not required.
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
        (address desToken, bytes memory oneInchCalldata) = abi.decode(
            payload,
            (address, bytes)
        );

        address inAsset = getAsset(inAssetIds[0]).assetAddress;

        if (inValues[0] == 0) {
            revert ZeroValue();
        }

        if (inAsset == address(0)) {
            revert ZeroValue();
        }

        uint256 dstTokenInitBal = IERC20(desToken).balanceOf(address(this));

        IERC20(inAsset).forceApprove(oneInchRouter, inValues[0]);
        (bool success, ) = oneInchRouter.call(oneInchCalldata);
        if (!success) {
            revert OneInchSwapFailed();
        }

        uint256 returnedAmt = IERC20(inAsset).balanceOf(address(this));
        uint256 receivedAmt = IERC20(desToken).balanceOf(address(this)) -
            dstTokenInitBal;

        // checking if any input token amount is left which was not swapped. Needs to be returned.
        if (returnedAmt > 0) {
            outValues = new uint256[](2);
            outValues[0] = returnedAmt;
            outValues[1] = receivedAmt;

            outAssetIds = new uint24[](2);
            outAssetIds[0] = inAssetIds[0];
            outAssetIds[1] = getAssetId(desToken);
        } else {
            outValues = new uint256[](1);
            outValues[0] = receivedAmt;

            outAssetIds = new uint24[](1);
            outAssetIds[0] = getAssetId(desToken);
        }
    }
}
