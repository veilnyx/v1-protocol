// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/Asset.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IAave} from "./IAave.sol";
import {IStaticAToken} from "./IStaticAToken.sol";
import {IStaticATokenFactory} from "./IStaticATokenFactory.sol";
import {IAToken} from "./IAToken.sol";
import {AssetAmount} from "../../interfaces/IAdaptor.sol";
import {IPool} from "../../interfaces/IPool.sol";

contract AaveV3Adaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    IAave public immutable aave;
    IStaticATokenFactory public immutable STATIC_A_TOKEN_FACTORY;

    uint8 constant ACTION_SUPPLY = 0;
    uint8 constant ACTION_WITHDRAW = 1;

    constructor(
        IAave aave_,
        IPool pool_,
        IStaticATokenFactory staticATokenFactory_
    ) AdaptorBase(pool_) {
        aave = aave_;
        STATIC_A_TOKEN_FACTORY = staticATokenFactory_;
    }

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

        uint8 action = abi.decode(payload, (uint8));

        outAssets = new AssetAmount[](1);

        if (action == ACTION_SUPPLY) {
            (outAssets[0].assetId, outAssets[0].value) = _supply(
                inAssets[0].assetId,
                inAssets[0].value
            );
        } else if (action == ACTION_WITHDRAW) {
            (outAssets[0].assetId, outAssets[0].value) = _withdraw(
                inAssets[0].assetId,
                inAssets[0].value
            );
        } else {
            revert InvalidAction();
        }
    }

    function _supply(
        uint24 inAssetId,
        uint256 inValue
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        Asset memory inAsset = getAsset(inAssetId);
        uint256 lendValue = inValue;

        if (lendValue == 0) {
            revert ZeroValue();
        }

        // underlying asset -> static aToken (non-rebasable) -> aToken (rebasable)
        // getting static aToken address for input token
        address underlyingToken = inAsset.assetAddress;
        address staticAToken = STATIC_A_TOKEN_FACTORY.getStaticAToken(
            underlyingToken
        );
        address aToken = IStaticAToken(staticAToken).aToken();

        if (aToken == address(0)) {
            revert UnsupportedAsset(inAsset.id);
        }
        uint256 underlyingTokenBal = IERC20(underlyingToken).balanceOf(
            address(this)
        );
        if (underlyingTokenBal < lendValue) {
            revert InsufficientBalance();
        }

        uint256 aTokensPreSupplyBal = IERC20(aToken).balanceOf(address(this));

        IERC20(underlyingToken).forceApprove(address(aave), lendValue);
        aave.supply({
            asset: underlyingToken,
            amount: lendValue,
            // will receive aToken tokens
            onBehalfOf: address(this),
            referralCode: 0
        });

        // rebasable aTokens by Aave
        uint256 aTokensPostSupplyBal = IERC20(aToken).balanceOf(address(this));
        uint256 aTokensReceived = aTokensPostSupplyBal - aTokensPreSupplyBal;

        // Step 2: Convert aToken(rebasable) to static tokens as supported by Veilnyx (non-rebasing)
        IERC20(aToken).forceApprove(staticAToken, aTokensReceived);
        uint256 staticATokenBal = IStaticAToken(staticAToken).deposit({
            assets: aTokensReceived,
            receiver: address(this),
            referralCode: 0,
            depositToAave: false
        });

        outAssetId = getAsset(staticAToken).id;
        outAssetValue = staticATokenBal;
    }

    function _withdraw(
        uint24 inAssetId,
        uint256 inValue
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        // Redeeming/Withdrawing
        Asset memory inAsset = getAsset(inAssetId);

        // static aToken (non-rebasable) -> aToken (rebasable) -> underlying asset
        address staticAToken = inAsset.assetAddress;
        address aToken = IStaticAToken(staticAToken).aToken();
        address underlyingAsset = IAToken(aToken).UNDERLYING_ASSET_ADDRESS();

        if (aToken == address(0)) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 staticATokenBal = IERC20(staticAToken).balanceOf(address(this));
        if (staticATokenBal < inValue) {
            revert InsufficientBalance();
        }

        (, uint256 amountToWithdraw) = IStaticAToken(staticAToken).redeem({
            shares: staticATokenBal,
            receiver: address(this),
            owner: address(this),
            withdrawFromAave: false
        });

        IERC20(aToken).forceApprove(address(aave), amountToWithdraw);
        uint256 underlyingAssetReceived = aave.withdraw({
            asset: underlyingAsset,
            amount: amountToWithdraw,
            to: address(this)
        });

        outAssetId = getAsset(underlyingAsset).id;
        outAssetValue = underlyingAssetReceived;
    }
}
