// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AdaptorBase} from "../base/AdaptorBase.sol";

struct PoolUnderlyingTokensInfo {
    address[] coins;
    uint256[] balances;
    uint24[] assetIds;
    uint8[] indexes;
}

error OneInchSwapFailed();

contract CurveNGSwapAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    address constant oneInchRouter = 0x11111112542D85B3EF69AE05771c2dCCff4fAa26;

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
        (address destinationToken, bytes memory routerCalldata) = abi.decode(
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

        IERC20(inAsset).forceApprove(oneInchRouter, inValues[0]);

        outValues = new uint256[](1);
        (bool success, bytes memory swapRes) = oneInchRouter.call(
            routerCalldata
        );
        if (!success) {
            revert OneInchSwapFailed();
        }
        (uint256 returnAmount, ) = abi.decode(swapRes, (uint256, uint256));
        outValues[0] = returnAmount;
        outAssetIds = new uint24[](1);
        outAssetIds[0] = getAssetId(destinationToken);
    }
}
