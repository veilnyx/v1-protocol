// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAdaptor, AssetAmount} from "../../interfaces/IAdaptor.sol";
import {IMorphoVault} from "./IMorphoVault.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset} from "../../libraries/AssetLogic.sol";
import {IPool} from "../../interfaces/IPool.sol";

contract MorphoVaultAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    enum Action {
        DEPOSIT,
        WITHDRAW
    }

    // Intentionally empty: no adaptor-specific constructor logic beyond base initialization.
    // solhint-disable-next-line no-empty-blocks
    constructor(IPool pool_) AdaptorBase(pool_) {}

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

        (Action action, address morphoVault) = abi.decode(
            payload,
            (Action, address)
        );

        outAssets = new AssetAmount[](1);

        if (action == Action.DEPOSIT) {
            (outAssets[0].assetId, outAssets[0].value) = _deposit(
                inAssets[0].assetId,
                inAssets[0].value,
                IMorphoVault(morphoVault)
            );
        } else if (action == Action.WITHDRAW) {
            (outAssets[0].assetId, outAssets[0].value) = _withdraw(
                inAssets[0].assetId,
                inAssets[0].value,
                IMorphoVault(morphoVault)
            );
        } else {
            revert InvalidAction();
        }
    }

    function _deposit(
        uint24 inAssetId,
        uint256 inValue,
        IMorphoVault morpho
    ) internal returns (uint24 outAssetId, uint256 outValue) {
        Asset memory inAsset = getAsset(inAssetId);
        getAsset(address(morpho)).id;

        // Checks
        if (inValue == 0) {
            revert ZeroValue();
        }

        if (inAsset.assetAddress != morpho.asset()) {
            revert UnsupportedAsset(inAsset.id);
        }

        if (IERC20(inAsset.assetAddress).balanceOf(address(this)) < inValue) {
            revert InsufficientBalance();
        }

        IERC20(inAsset.assetAddress).forceApprove(address(morpho), inValue);
        uint256 shares = morpho.deposit(inValue, address(this));
        outValue = shares;
        outAssetId = getAsset(address(morpho)).id;
        return (outAssetId, outValue);
    }

    function _withdraw(
        uint24 inAssetId,
        uint256 inValue,
        IMorphoVault morpho
    ) internal returns (uint24 outAssetId, uint256 outValue) {
        Asset memory inAsset = getAsset(inAssetId);

        // Checks
        if (inValue == 0) {
            revert ZeroValue();
        }

        if (inAsset.assetAddress != address(morpho)) {
            revert UnsupportedAsset(inAsset.id);
        }

        IERC20(inAsset.assetAddress).forceApprove(address(morpho), inValue);
        uint256 loanTokens = morpho.redeem(
            inValue,
            address(this),
            address(this)
        );
        outAssetId = getAsset(address(morpho.asset())).id;
        outValue = loanTokens;
        return (outAssetId, outValue);
    }
}
