// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.24;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ILido} from "./ILido.sol";
import {IWithdrawQueueERC721} from "./IWithdrawQueueERC721.sol";
import {IWstEthToken} from "./IWstEthToken.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum Action {
    STAKE,
    UNSTAKE
}

contract LidoAdaptor is AdaptorBase {
    ILido public immutable iLido;
    IWithdrawQueueERC721 public immutable iWithdrawQueueERC721;
    address public immutable weth;
    address public immutable stEth;
    address public immutable wstEth;

    uint256 public constant HOLESKY_CHAINID = 17000;
    uint256 public constant MAINNET_CHAINID = 1;

    constructor(
        address lido_,
        address weth_,
        // represents the staked ETH token
        address stEth_,
        // represents the share of stETH tokens in Lido (wrapping stETH -> wstETH)
        address wstEth_,
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
        (Action action, address withdrawAddress) = abi.decode(
            payload,
            (Action, address)
        );

        if (action == Action.STAKE) {
            (outAssetIds, outValues) = _stake(inAssetIds[0], inValues[0]);
        } else if (action == Action.UNSTAKE) {
            (outAssetIds, outValues) = _unstake(
                inAssetIds[0],
                inValues[0],
                withdrawAddress
            );
        } else {
            revert InvalidAction();
        }
    }

    function _stake(
        uint24 inAssetId,
        uint256 stakeValue
    )
        internal
        returns (uint24[] memory outAssetIds, uint256[] memory outValues)
    {
        Asset memory inAsset = getAsset(inAssetId);

        if (stakeValue == 0) {
            revert ZeroValue();
        }

        if (inAsset.assetAddress != weth) {
            revert UnsupportedAsset(inAssetId);
        }

        // Staking request
        // unwrapping weth
        IWToken(weth).withdraw(stakeValue);

        // will receive shares of stEth token in Lido. stETH will is a rebasing token.
        uint256 stEthShares = iLido.submit{value: stakeValue}(address(0));
        // converting shares to stEth tokens (rebasing token)
        uint256 stEthTokens = iLido.getPooledEthByShares(stEthShares);

        // wrapping into wstEth for keeping balances constant
        IERC20(stEth).approve(wstEth, stEthTokens);
        uint256 wstEthTokens = IWstEthToken(wstEth).wrap(stEthTokens);

        outValues = new uint256[](1);
        outAssetIds = new uint24[](1);

        outAssetIds[0] = getAsset(wstEth).id;
        outValues[0] = wstEthTokens;
    }

    function _unstake(
        uint24 inAssetId,
        uint256 unstakeValue,
        address withdrawAddress
    )
        internal
        returns (uint24[] memory outAssetIds, uint256[] memory outValues)
    {
        if (
            block.chainid != MAINNET_CHAINID && block.chainid != HOLESKY_CHAINID
        ) {
            revert ILido.LidoWithdrawNotSupportedOnChain(block.chainid);
        }

        Asset memory inAsset = getAsset(inAssetId);

        // Unstaking request (outputs an NFT)
        if (inAsset.assetAddress != wstEth) {
            revert UnsupportedAsset(inAsset.id);
        }

        // Withdraw address cannot be a Pool's addr as Lido returns `unstEth` NFTs because the withdrawal req. is queued on their end.
        if (withdrawAddress == address(0)) {
            revert ILido.ZeroAddress();
        }

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = unstakeValue;

        IWstEthToken(wstEth).approve(
            address(iWithdrawQueueERC721),
            unstakeValue
        );
        iWithdrawQueueERC721.requestWithdrawalsWstETH(amounts, withdrawAddress);

        outAssetIds = new uint24[](0);
        outValues = new uint256[](0);
    }

    /// @dev only for enabling `testWstEthUnstakingOnLido()` test. Pls comment this out for production use.
    // Allow Lido adaptor to receive unwrapped Ether, to send to Lido for staking
    // receive() external payable {}
}
