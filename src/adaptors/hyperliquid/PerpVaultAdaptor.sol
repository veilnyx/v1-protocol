// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAdaptor, AssetAmount} from "../../interfaces/IAdaptor.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset} from "../../libraries/AssetLogic.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {PerpVault} from "./PerpVault.sol";

/// @title PerpVaultAdaptor - shielded access to a PerpVault
/// @notice Deliberately shaped like MorphoVaultAdaptor, because the note mechanics
///         are identical: hand the Pool back an ERC20 and it commits
///         Poseidon(assetId, refundAddress, value) for the sender. Share counts are
///         not known until the vault prices them, which is exactly what the
///         CALL_ADAPTOR refund path is for.
/// @dev Runs under delegatecall from AdaptorHandler, so `address(this)` is the
///      handler. The vault is a SEPARATE contract and is called normally, which is
///      what gives each strategy its own HyperCore account.
/// @dev STATELESS - no storage vars.
contract PerpVaultAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    enum Action {
        DEPOSIT,
        REDEEM
    }

    // solhint-disable-next-line no-empty-blocks
    constructor(IPool pool_) AdaptorBase(pool_) {}

    function handleAssets(AssetAmount[] calldata inAssets, bytes calldata payload)
        external
        payable
        virtual
        override
        returns (AssetAmount[] memory outAssets)
    {
        if (inAssets.length != 1) {
            revert InvalidInputAssetLength(uint8(inAssets.length), 1);
        }

        (Action action, address vault) = abi.decode(payload, (Action, address));

        outAssets = new AssetAmount[](1);

        if (action == Action.DEPOSIT) {
            (outAssets[0].assetId, outAssets[0].value) =
                _deposit(inAssets[0].assetId, inAssets[0].value, PerpVault(vault));
        } else if (action == Action.REDEEM) {
            (outAssets[0].assetId, outAssets[0].value) =
                _redeem(inAssets[0].assetId, inAssets[0].value, PerpVault(vault));
        } else {
            revert InvalidAction();
        }
    }

    function _deposit(uint24 inAssetId, uint256 inValue, PerpVault vault)
        internal
        returns (uint24 outAssetId, uint256 outValue)
    {
        Asset memory inAsset = getAsset(inAssetId);

        if (inValue == 0) revert ZeroValue();
        if (inAsset.assetAddress != address(vault.asset())) {
            revert UnsupportedAsset(inAsset.id);
        }
        if (IERC20(inAsset.assetAddress).balanceOf(address(this)) < inValue) {
            revert InsufficientBalance();
        }

        IERC20(inAsset.assetAddress).forceApprove(address(vault), inValue);
        outValue = vault.deposit(inValue, address(this));
        outAssetId = getAsset(address(vault)).id;
    }

    function _redeem(uint24 inAssetId, uint256 inValue, PerpVault vault)
        internal
        returns (uint24 outAssetId, uint256 outValue)
    {
        Asset memory inAsset = getAsset(inAssetId);

        if (inValue == 0) revert ZeroValue();
        if (inAsset.assetAddress != address(vault)) {
            revert UnsupportedAsset(inAsset.id);
        }

        // Reverts if the vault's idle buffer cannot cover the payout. Failing loudly
        // is deliberate: the CLAIM-token queue for that case is not built yet.
        outValue = vault.redeem(inValue, address(this));
        outAssetId = getAsset(address(vault.asset())).id;
    }
}
