// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.24;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ILido} from "./ILido.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IWstEthToken} from "./IWstEthToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/Test.sol";

contract LidoAdaptor is AdaptorBase {
    error UnsupportedAsset(uint24 assetId);
    error OnlyWETHSupported();
    error ZeroValues();

    ILido public immutable iLido;
    address public immutable weth;
    address public immutable stEth;
    address public immutable wstEth;

    constructor(
        address lido_,
        address weth_,
        address stEth_, // represents the staked ETH token
        address wstEth_, // represents the share of stETH tokens in Lido (wrapping stETH -> wstETH)
        address pool_
    ) AdaptorBase(pool_) {
        iLido = ILido(lido_);
        weth = weth_;
        stEth = stEth_;
        wstEth = wstEth_;
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
        Asset memory inAsset = getAsset(inAssetIds[0]);
        Asset memory outAsset = getAsset(wstEth);
        uint256 stakeValue = inValues[0];

        if (inAsset.assetAddress != weth) {
            revert OnlyWETHSupported();
        }

        if (!inAsset.isSupported) {
            revert UnsupportedAsset(inAssetIds[0]);
        }

        if (stakeValue == 0) {
            revert ZeroValues();
        }

        if (!outAsset.isSupported) {
            revert UnsupportedAsset(outAsset.id);
        }

        // unwrapping weth
        IWToken(weth).withdraw(stakeValue);
        outValues = new uint256[](1);
        outAssetIds = new uint24[](1);

        uint256 stEthShares = iLido.submit{value: stakeValue}(address(0)); // shares of stEth token in Lido. Shares do not change with rebasing.
        
        uint256 stEthTokens = iLido.getPooledEthByShares(stEthShares); // converting shares to stEth tokens (rebasing token)
        
        // wrapping into wstEth for keeping balances constant
        IERC20(stEth).approve(wstEth, stEthTokens);
        uint256 wstEthTokens = IWstEthToken(wstEth).wrap(
            stEthTokens
        );

        console.log(
            "Bal. of wstETH:",
            IWstEthToken(wstEth).balanceOf(address(this))
        );
        console.log(
            "Bal. of stETH:",
            IERC20(stEth).balanceOf(
                address(this)
            )
        );

        outValues[0] = wstEthTokens;
        outAssetIds[0] = outAsset.id;
    }
}
