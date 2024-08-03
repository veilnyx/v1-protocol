// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.24;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ILido} from "./ILido.sol";
import {IWithdrawQueueERC721} from "./IWithdrawQueueERC721.sol";
import {IWstEthToken} from "./IWstEthToken.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/Test.sol";

contract LidoAdaptor is AdaptorBase {
    error UnsupportedAsset(uint24 assetId);
    error ZeroValues();
    error ZeroAddress();

    ILido public immutable iLido;
    IWithdrawQueueERC721 public immutable iWithdrawQueueERC721;
    address public immutable weth;
    address public immutable stEth;
    address public immutable wstEth;

    constructor(
        address lido_,
        address weth_,
        address stEth_, // represents the staked ETH token
        address wstEth_, // represents the share of stETH tokens in Lido (wrapping stETH -> wstETH)
        address withdrawQueueERC721_,
        address pool_
    ) AdaptorBase(pool_) {
        iLido = ILido(lido_);
        iWithdrawQueueERC721 = IWithdrawQueueERC721(withdrawQueueERC721_);
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
        uint256 stakeValue = inValues[0];

        if (!inAsset.isSupported) {
            revert UnsupportedAsset(inAssetIds[0]);
        }

        if (stakeValue == 0) {
            revert ZeroValues();
        }

        if (inAsset.assetAddress == weth) {
            // Staking request
            // unwrapping weth
            IWToken(weth).withdraw(stakeValue);

            uint256 stEthShares = iLido.submit{value: stakeValue}(address(0)); // shares of stEth token in Lido. Shares do not change with rebasing.
            uint256 stEthTokens = iLido.getPooledEthByShares(stEthShares); // converting shares to stEth tokens (rebasing token)
            // wrapping into wstEth for keeping balances constant
            IERC20(stEth).approve(wstEth, stEthTokens);
            uint256 wstEthTokens = IWstEthToken(wstEth).wrap(stEthTokens);

            // initializing the out token arrays
            Asset memory outAsset = getAsset(wstEth);
            if (!outAsset.isSupported) {
                revert UnsupportedAsset(outAsset.id);
            }

            outValues = new uint256[](1);
            outAssetIds = new uint24[](1);

            outAssetIds[0] = outAsset.id;
            outValues[0] = wstEthTokens;
        } else {
            // Unstaking request
            if (inAsset.assetAddress != wstEth) {
                revert UnsupportedAsset(inAsset.id); // If not wEth, only wstEth is supported for claiming `unstEth` NFTs from Lido
            }

            address withdrawalAddress = abi.decode(payload, (address));
            if (withdrawalAddress == address(0)) {
                revert ZeroAddress();
            }

            uint256[] memory amounts = new uint256[](1);
            amounts[0] = stakeValue;

            IWstEthToken(wstEth).approve(
                address(iWithdrawQueueERC721),
                stakeValue
            ); // needed by `Lido::requestWithdrawalsWstETH()`

            iWithdrawQueueERC721.requestWithdrawalsWstETH(
                amounts,
                withdrawalAddress
            );

            outAssetIds = new uint24[](0);
            outValues = new uint256[](0);
        }

        console.log(
            "Bal. of wstETH:",
            IWstEthToken(wstEth).balanceOf(address(this))
        );
    }

    /// @dev only for enabling `testWstEthUnstakingOnLido()` test. Pls comment this out for production use.
    // Allow Lido adaptor to receive unwrapped Ether
    // receive() external payable {}
}
