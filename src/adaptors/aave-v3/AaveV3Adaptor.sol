// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/Asset.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IAave} from "./IAave.sol";
import {IStaticAToken} from "./IStaticAToken.sol";
import {IStaticATokenFactory} from "./IStaticATokenFactory.sol";
import {IAToken} from "./IAToken.sol";

contract AaveV3Adaptor is AdaptorBase {
    IAave public immutable aave;
    address public immutable STATIC_A_TOKEN_FACTORY;

    uint8 constant ACTION_SUPPLY = 0;
    uint8 constant ACTION_WITHDRAW = 1;

    constructor(
        address aave_,
        address pool_,
        address staticATokenFactory_
    ) AdaptorBase(pool_) {
        aave = IAave(aave_);
        STATIC_A_TOKEN_FACTORY = staticATokenFactory_;
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
        uint8 action = abi.decode(payload, (uint8));

        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);

        if (action == ACTION_SUPPLY) {
            (outAssetIds[0], outValues[0]) = _supply(
                inAssetIds[0],
                uint256(inValues[0])
            );
        } else if (action == ACTION_WITHDRAW) {
            (outAssetIds[0], outValues[0]) = _withdraw(
                inAssetIds[0],
                uint256(inValues[0])
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

        // underlying asset -> static aToken -> aToken
        // getting static aToken address for input token
        address underlyingToken = inAsset.assetAddress;
        address staticAToken = IStaticATokenFactory(STATIC_A_TOKEN_FACTORY)
            .getStaticAToken(underlyingToken);
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

        IERC20(underlyingToken).approve(address(aave), lendValue);
        aave.supply({
            asset: underlyingToken,
            amount: lendValue,
            // will receive aToken tokens
            onBehalfOf: address(this),
            referralCode: 0
        });

        // rebasable aTokens by Aave
        uint256 aTokensReceived = IERC20(aToken).balanceOf(address(this));

        // Step 2: Convert aToken(rebasable) to static tokens as supported by Labyrith
        IERC20(aToken).approve(staticAToken, aTokensReceived);
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

        // static aToken -> aToken -> underlying asset
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

        IERC20(aToken).approve(address(aave), amountToWithdraw);
        uint256 underlyingAssetReceived = aave.withdraw({
            asset: underlyingAsset,
            amount: amountToWithdraw,
            to: address(this)
        });

        outAssetId = getAsset(underlyingAsset).id;
        outAssetValue = underlyingAssetReceived;
    }
}
