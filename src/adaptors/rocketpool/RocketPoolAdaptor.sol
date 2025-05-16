// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {IRocketSwapRouter} from "./IRocketSwapRouter.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error InsufficientStakingAmt(uint256 stakingAmt, uint256 minimumDeposit);

enum Action {
    STAKE,
    UNSTAKE
}

contract RocketPoolAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    IRocketSwapRouter public immutable rocketSwapRouter;
    address public immutable WETH;
    address public immutable rETH;
    uint256 public constant MINIMUM_DEPOSIT = 0.01 ether;

    constructor(
        address rocketPoolRouter_,
        address rEth_,
        address wEth_,
        address labyrinthPool_
    ) AdaptorBase(labyrinthPool_) {
        rocketSwapRouter = IRocketSwapRouter(rocketPoolRouter_);
        rETH = rEth_;
        WETH = wEth_;
    }

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
        (
            Action action,
            uint256 uniswapPortion,
            uint256 balancerPortion,
            uint256 minTokensOut
        ) = abi.decode(payload, (Action, uint256, uint256, uint256));

        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);

        if (action == Action.STAKE) {
            (outAssetIds, outValues) = _stake(
                inAssetIds[0],
                inValues[0],
                uniswapPortion,
                balancerPortion,
                minTokensOut
            );
        } else if (action == Action.UNSTAKE) {
            (outAssetIds, outValues) = _unstake(
                inAssetIds[0],
                inValues[0],
                uniswapPortion,
                balancerPortion,
                minTokensOut
            );
        } else {
            revert InvalidAction();
        }
    }

    function _stake(
        uint24 inAssetId,
        uint256 stakeValue,
        uint256 uniswapPortion,
        uint256 balancerPortion,
        uint256 minTokensOut
    )
        internal
        returns (uint24[] memory outAssetIds, uint256[] memory outValues)
    {
        Asset memory inAsset = getAsset(inAssetId);
        if (stakeValue < MINIMUM_DEPOSIT) {
            revert InsufficientStakingAmt(stakeValue, MINIMUM_DEPOSIT);
        }

        if (inAsset.assetAddress != WETH) {
            revert UnsupportedAsset(inAssetId);
        }

        // Staking request
        // unwrapping weth
        uint256 rEthBalBeforeStaking = IERC20(rETH).balanceOf(address(this));
        IWToken(WETH).withdraw(stakeValue);

        rocketSwapRouter.swapTo{value: stakeValue}(
            uniswapPortion,
            balancerPortion,
            minTokensOut,
            minTokensOut
        );

        uint256 rEthBalAfterStaking = IERC20(rETH).balanceOf(address(this));

        // initializing the out token arrays
        Asset memory outAsset = getAsset(rETH);

        outValues = new uint256[](1);
        outAssetIds = new uint24[](1);

        outAssetIds[0] = outAsset.id;
        outValues[0] = rEthBalAfterStaking - rEthBalBeforeStaking;
    }

    function _unstake(
        uint24 inAssetId,
        uint256 unstakeValue,
        uint256 uniswapPortion,
        uint256 balancerPortion,
        uint256 minTokensOut
    )
        internal
        returns (uint24[] memory outAssetIds, uint256[] memory outValues)
    {
        Asset memory inAsset = getAsset(inAssetId);
        if (unstakeValue == 0) {
            revert ZeroValue();
        }

        if (inAsset.assetAddress != rETH) {
            revert UnsupportedAsset(inAssetId);
        }

        // Unstaking request
        uint256 ethBalBeforeUnstaking = address(this).balance;

        IERC20(rETH).forceApprove(address(rocketSwapRouter), unstakeValue);
        rocketSwapRouter.swapFrom(
            uniswapPortion,
            balancerPortion,
            minTokensOut,
            minTokensOut,
            unstakeValue
        );

        uint256 ethBalAfterUnstaking = address(this).balance;
        outValues = new uint256[](1);
        outAssetIds = new uint24[](1);

        outValues[0] = ethBalAfterUnstaking - ethBalBeforeUnstaking;
        // wrapping the received ETH to return to Labyrinth
        IWToken(WETH).deposit{value: outValues[0]}();
        outAssetIds[0] = getAsset(WETH).id;
    }

    /// @dev only for enabling tests bypassing protocol. Pls comment this out for production use.
    // Allow RocketPool adaptor to receive unwrapped Ether, to send to Lido for staking
    // receive() external payable {}
}
