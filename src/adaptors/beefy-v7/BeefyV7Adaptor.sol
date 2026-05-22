// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBeefyVault} from "./IBeefyVault.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset} from "../../libraries/Asset.sol";
import {AssetAmount} from "../../interfaces/IAdaptor.sol";
import {IPool} from "../../interfaces/IPool.sol";

contract BeefyV7Adaptor is AdaptorBase {
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

        (uint8 action, address vault) = abi.decode(payload, (uint8, address));

        outAssets = new AssetAmount[](1);

        if (action == uint8(Action.DEPOSIT)) {
            (outAssets[0].assetId, outAssets[0].value) = _deposit(
                inAssets[0].assetId,
                inAssets[0].value,
                vault
            );
        } else if (action == uint8(Action.WITHDRAW)) {
            (outAssets[0].assetId, outAssets[0].value) = _withdraw(
                inAssets[0].assetId,
                inAssets[0].value,
                vault
            );
        } else {
            revert InvalidAction();
        }
    }

    function _deposit(
        uint24 inAssetId,
        uint256 inValue,
        address vault
    ) internal returns (uint24 outAssetId, uint256 outValue) {
        Asset memory inAsset = getAsset(inAssetId);
        address wantToken = IBeefyVault(vault).want();

        if (inValue == 0) {
            revert ZeroValue();
        }

        if (inAsset.assetAddress != wantToken) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 sharesBalBeforeDeposit = IERC20(vault).balanceOf(address(this));
        IERC20(inAsset.assetAddress).forceApprove(vault, inValue);
        IBeefyVault(vault).deposit(inValue);
        uint256 sharesBalAfterDeposit = IERC20(vault).balanceOf(address(this));

        outAssetId = getAsset(vault).id;
        outValue = sharesBalAfterDeposit - sharesBalBeforeDeposit;
        return (outAssetId, outValue);
    }

    function _withdraw(
        uint24 inAssetId,
        uint256 inValue,
        address vault
    ) internal returns (uint24 outAssetId, uint256 outValue) {
        Asset memory inAsset = getAsset(inAssetId);
        address wantToken = IBeefyVault(vault).want();

        if (inValue == 0) {
            revert ZeroValue();
        }

        if (inAsset.assetAddress != vault) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 wantTokenBalBeforeWithdraw = IERC20(wantToken).balanceOf(
            address(this)
        );
        IERC20(inAsset.assetAddress).forceApprove(vault, inValue);
        IBeefyVault(vault).withdraw(inValue);
        uint256 wantTokenBalAfterWithdraw = IERC20(wantToken).balanceOf(
            address(this)
        );

        outAssetId = getAsset(wantToken).id;
        outValue = wantTokenBalAfterWithdraw - wantTokenBalBeforeWithdraw;
        return (outAssetId, outValue);
    }
}
