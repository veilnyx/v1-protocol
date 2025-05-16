// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBeefyVault} from "./IBeefyVault.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset} from "../../libraries/Asset.sol";

enum Action {
    DEPOSIT,
    WITHDRAW
}

contract BeefyV7Adaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    constructor(address pool_) AdaptorBase(pool_) {}

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
        (uint8 action, address vault) = abi.decode(payload, (uint8, address));

        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);

        if (action == uint8(Action.DEPOSIT)) {
            (outAssetIds[0], outValues[0]) = _deposit(
                inAssetIds[0],
                inValues[0],
                vault
            );
        } else if (action == uint8(Action.WITHDRAW)) {
            (outAssetIds[0], outValues[0]) = _withdraw(
                inAssetIds[0],
                inValues[0],
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

        if (IERC20(inAsset.assetAddress).balanceOf(address(this)) < inValue) {
            revert InsufficientBalance();
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

        if (IERC20(inAsset.assetAddress).balanceOf(address(this)) < inValue) {
            revert InsufficientBalance();
        }

        if (inAsset.assetAddress != vault) {
            revert UnsupportedAsset(inAsset.id);
        }

        IERC20(inAsset.assetAddress).forceApprove(vault, inValue);
        IBeefyVault(vault).withdraw(inValue);

        outAssetId = getAsset(wantToken).id;
        outValue = IERC20(wantToken).balanceOf(address(this));
        return (outAssetId, outValue);
    }
}
