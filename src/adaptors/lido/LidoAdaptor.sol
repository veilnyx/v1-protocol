// SPDX-License-Identifier: LicenseRef-BUSL

pragma solidity 0.8.24;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/AssetLogic.sol";
import {ILido} from "./ILido.sol";
import {IWithdrawQueueERC721} from "./IWithdrawQueueERC721.sol";
import {IWstEthToken} from "./IWstEthToken.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AssetAmount} from "../../interfaces/IAdaptor.sol";
import {IPool} from "../../interfaces/IPool.sol";

contract LidoAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    enum Action {
        STAKE,
        UNSTAKE
    }

    ILido public immutable iLido;
    IWithdrawQueueERC721 public immutable iWithdrawQueueERC721;
    IWToken public immutable weth;
    IERC20 public immutable stEth;
    IERC20 public immutable wstEth;

    uint256 public constant HOLESKY_CHAINID = 17000;
    uint256 public constant MAINNET_CHAINID = 1;

    constructor(
        ILido lido_,
        IWToken weth_,
        // represents the staked ETH token
        IERC20 stEth_,
        // represents the share of stETH tokens in Lido (wrapping stETH -> wstETH). stETH is a rebasing token, wstETH is non-rebasing and will keep the balance of shares constant. This is required for easier integration with Veilnyx as it doesn't have to account for rebasing tokens.
        IERC20 wstEth_,
        IWithdrawQueueERC721 withdrawQueueERC721_,
        IPool pool_
    ) AdaptorBase(pool_) {
        iLido = lido_;
        iWithdrawQueueERC721 = withdrawQueueERC721_;
        weth = weth_;
        stEth = stEth_;
        wstEth = wstEth_;
    }

    /// @notice For unstaking from Lido, users will receive an NFT representing their withdrawal request as the unstaking process is queued on Lido's end. Once the unstaking process is complete on Lido's end, users can redeem their NFT for their staked ETH. This will leak privacy as the unstaking process is not atomic and will require a `withdrawAddress`. However, this is a constraint by Lido's design.
    function handleAssets(
        AssetAmount[] calldata inAssets,
        bytes calldata payload
    )
        external
        payable
        virtual
        override
        returns (AssetAmount[] memory outAssets)
    {
        if (inAssets.length != 1) {
            revert InvalidInputAssetLength(uint8(inAssets.length), 1);
        }

        (Action action, address withdrawAddress) = abi.decode(
            payload,
            (Action, address)
        );

        uint24[] memory outAssetIds;
        uint256[] memory outValues;

        if (action == Action.STAKE) {
            (outAssetIds, outValues) = _stake(
                inAssets[0].assetId,
                inAssets[0].value
            );
        } else if (action == Action.UNSTAKE) {
            (outAssetIds, outValues) = _unstake(
                inAssets[0].assetId,
                inAssets[0].value,
                withdrawAddress
            );
        } else {
            revert InvalidAction();
        }

        outAssets = new AssetAmount[](outAssetIds.length);
        for (uint256 i; i < outAssetIds.length; i++) {
            outAssets[i] = AssetAmount(outAssetIds[i], outValues[i]);
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

        if (inAsset.assetAddress != address(weth)) {
            revert UnsupportedAsset(inAssetId);
        }

        // Staking request
        // unwrapping weth
        weth.withdraw(stakeValue);

        // will receive shares of stEth token in Lido. stETH will is a rebasing token.
        uint256 stEthShares = iLido.submit{value: stakeValue}(address(0));
        // converting shares to stEth tokens (rebasing token)
        uint256 stEthTokens = iLido.getPooledEthByShares(stEthShares);

        // wrapping into wstEth for keeping balances constant (non-rebasing)
        stEth.forceApprove(address(wstEth), stEthTokens);
        uint256 wstEthTokens = IWstEthToken(address(wstEth)).wrap(stEthTokens);

        outValues = new uint256[](1);
        outAssetIds = new uint24[](1);

        outAssetIds[0] = getAsset(address(wstEth)).id;
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
        if (inAsset.assetAddress != address(wstEth)) {
            revert UnsupportedAsset(inAsset.id);
        }

        // Withdraw address cannot be a Pool's addr as Lido returns `unstEth` NFTs because the withdrawal req. is queued on their end.
        if (withdrawAddress == address(0)) {
            revert ILido.ZeroAddress();
        }

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = unstakeValue;

        wstEth.forceApprove(address(iWithdrawQueueERC721), unstakeValue);
        iWithdrawQueueERC721.requestWithdrawalsWstETH(amounts, withdrawAddress);

        outAssetIds = new uint24[](0);
        outValues = new uint256[](0);
    }

    /// @dev only for enabling `testWstEthUnstakingOnLido()` test. Pls comment this out for production use.
    // Allow Lido adaptor to receive unwrapped Ether, to send to Lido for staking
    // Intentionally empty: accepts native ETH after WETH unwrap before Lido staking.
    // solhint-disable-next-line no-empty-blocks
    // receive() external payable {}
}
