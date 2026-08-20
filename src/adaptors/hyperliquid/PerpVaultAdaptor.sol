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
        REDEEM,
        CLAIM
    }

    /// @dev Spending a CLAIM note when the unwind has funded none of it would burn
    ///      a proof for nothing, so refuse rather than round-trip the note.
    error NothingSettled();

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

        if (action == Action.DEPOSIT) {
            outAssets = new AssetAmount[](1);
            (outAssets[0].assetId, outAssets[0].value) =
                _deposit(inAssets[0].assetId, inAssets[0].value, PerpVault(vault));
        } else if (action == Action.REDEEM) {
            outAssets = _redeem(inAssets[0].assetId, inAssets[0].value, PerpVault(vault));
        } else if (action == Action.CLAIM) {
            outAssets = _claim(inAssets[0].assetId, inAssets[0].value, PerpVault(vault));
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

    /// @dev Returns ONE asset when the buffer covers the whole exit, and TWO when
    ///      it does not: the asset paid now, plus a CLAIM note for the shares left
    ///      escrowed. Returning only the first would strand the CLAIM at the
    ///      handler — minted, never committed as a note, and sitting where a later
    ///      caller could take it.
    function _redeem(uint24 inAssetId, uint256 inValue, PerpVault vault)
        internal
        returns (AssetAmount[] memory outAssets)
    {
        Asset memory inAsset = getAsset(inAssetId);

        if (inValue == 0) revert ZeroValue();
        if (inAsset.assetAddress != address(vault)) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 escrowedBefore = vault.claimSharesEscrowed();
        uint256 paid = vault.redeem(inValue, address(this));
        uint256 queued = vault.claimSharesEscrowed() - escrowedBefore;

        if (queued == 0) {
            outAssets = new AssetAmount[](1);
            outAssets[0] = AssetAmount(getAsset(address(vault.asset())).id, paid);
        } else {
            outAssets = new AssetAmount[](2);
            outAssets[0] = AssetAmount(getAsset(address(vault.asset())).id, paid);
            outAssets[1] = AssetAmount(getAsset(address(vault.claimToken())).id, queued);
        }
    }

    /// @dev Convert a CLAIM note into asset at the settled rate. Settlement is
    ///      partial whenever the unwind has returned less than the full amount, so
    ///      this claims what is settled and hands back a fresh CLAIM note for the
    ///      remainder rather than reverting and stranding the holder until the
    ///      queue clears completely.
    function _claim(uint24 inAssetId, uint256 inValue, PerpVault vault)
        internal
        returns (AssetAmount[] memory outAssets)
    {
        Asset memory inAsset = getAsset(inAssetId);

        if (inValue == 0) revert ZeroValue();
        if (inAsset.assetAddress != address(vault.claimToken())) {
            revert UnsupportedAsset(inAsset.id);
        }

        // Advance settlement first: asset may have landed since the last call, and
        // claim() would do this anyway. Reading after it means we do not understate
        // what is claimable right now.
        vault.fundClaims();
        uint256 settled = vault.claimSharesSettled();
        uint256 toClaim = inValue < settled ? inValue : settled;
        if (toClaim == 0) revert NothingSettled();

        uint256 paid = vault.claim(toClaim, address(this));
        uint256 leftover = inValue - toClaim;

        if (leftover == 0) {
            outAssets = new AssetAmount[](1);
            outAssets[0] = AssetAmount(getAsset(address(vault.asset())).id, paid);
        } else {
            outAssets = new AssetAmount[](2);
            outAssets[0] = AssetAmount(getAsset(address(vault.asset())).id, paid);
            outAssets[1] = AssetAmount(inAssetId, leftover);
        }
    }
}
