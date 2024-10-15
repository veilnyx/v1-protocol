// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAdaptor} from "../../interfaces/IAdaptor.sol";
import {IMorphoVault} from "./IMorphoVault.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset} from "../../libraries/Asset.sol";

enum Action {
    DEPOSIT,
    WITHDRAW
}

contract MorphoVaultAdaptor is AdaptorBase {
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
        (Action action, address morphoVault) = abi.decode(
            payload,
            (Action, address)
        );

        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);

        if (action == Action.DEPOSIT) {
            (outAssetIds[0], outValues[0]) = _deposit(
                inAssetIds[0],
                inValues[0],
                IMorphoVault(morphoVault)
            );
        } else if (action == Action.WITHDRAW) {
            (outAssetIds[0], outValues[0]) = _withdraw(
                inAssetIds[0],
                uint256(inValues[0]),
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

        if (IERC20(inAsset.assetAddress).balanceOf(address(this)) < inValue) {
            revert InsufficientBalance();
        }

        if (inAsset.assetAddress != morpho.asset()) {
            revert UnsupportedAsset(inAsset.id);
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

        if (IERC20(inAsset.assetAddress).balanceOf(address(this)) < inValue) {
            revert InsufficientBalance();
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

    /////////////////////////////
    //// View Functions /////////
    //////////////////////////////

    /// @notice This function returns the amount of shares that would be exchanged by the vault for the amount of assets provided.
    function convertToShares(
        address morphoVault,
        uint256 assets
    ) external view returns (uint256) {
        uint256 shares = IMorphoVault(morphoVault).convertToShares(assets);
        return shares;
    }

    /// @notice This function returns the amount of assets that would be exchanged by the vault for the amount of shares provided.
    function convertToAssets(
        address morphoVault,
        uint256 shares
    ) external view returns (uint256) {
        uint256 assets = IMorphoVault(morphoVault).convertToAssets(shares);
        return assets;
    }

    /// @notice Returns the address of the underlying token used for the vault for accounting, depositing, withdrawing.
    function getLoanToken(address morphoVault) external view returns (address) {
        return IMorphoVault(morphoVault).asset();
    }
}
