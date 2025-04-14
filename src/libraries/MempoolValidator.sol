// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType} from "../libraries/ShieldedTransaction.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";
import {IPool} from "../interfaces/IPool.sol";

library MempoolValidator {
    using EnumerableSet for EnumerableSet.UintSet;
    using ShieldedTransactionLogic for ShieldedTransaction;
    using SafeERC20 for IERC20;

    error InvalidStx();
    error DuplicateStx(uint256 stxHash);
    error LabyrinthPoolAddrNotInitialized();
    error NonDepositTxReceivedFromPublicAddr(address sender);
    error InsufficientFee(uint256 given, uint256 required);
    error ZeroValue();
    error InactiveAsset(uint24 assetId);
    error UnsupportedAsset(uint24 assetId);

    function validityChecksBeforeAddingSTXToMempool(
        ShieldedTransaction calldata stx,
        uint256 stxHashPI,
        IPool pool,
        EnumerableSet.UintSet storage _stxHashes,
        address gateway,
        uint256 mempoolExitFee
    ) public {
        if (address(pool) == address(0)) {
            revert LabyrinthPoolAddrNotInitialized();
        }

        // validate the correlation btw the stx and public inputs
        if (stx.hash() != stxHashPI) {
            revert InvalidStx();
        }

        // check if stx is already in mempool
        if (_stxHashes.contains(stxHashPI)) {
            revert DuplicateStx(stxHashPI);
        }

        // Non-deposit STX are only supported through Account Abstraction (ERC4337) infra
        // This is done to enforce privacy by not exposing the user's public address in the tx traces and to manage fee reimbursement to both paymaster and verification tracker service by the Laby pool, using the `stx.feeData`.
        if (stx.txType != ShieldedTransactionType.DEPOSIT) {
            // msg.sender should only be the Gateway contract
            if (msg.sender != gateway) {
                revert NonDepositTxReceivedFromPublicAddr(msg.sender);
            }
        }

        // Asset checks and transfer for DEPOSIT tx
        if (stx.txType == ShieldedTransactionType.DEPOSIT) {
            // Mempool exit fee check
            // User pays mempool exit fee in ETH for deposit tx only. Other tx types are handled by the ERC4337 infra.
            if (msg.value < mempoolExitFee) {
                revert InsufficientFee(msg.value, mempoolExitFee);
            }

            for (uint i = 0; i < stx.pubAssets.length; i++) {
                (uint24 assetId, uint224 value) = decodeAsset(stx.pubAssets[i]);

                Asset memory asset = checkIfAssetValid(assetId, pool);

                if (value == 0) {
                    revert ZeroValue();
                }

                // Transfer deposit assets from sender's wallet to the mempool
                IERC20(asset.assetAddress).safeTransferFrom(
                    msg.sender,
                    address(this),
                    value
                );
            }
        }
    }

    function checkIfAssetValid(
        uint24 assetId,
        IPool pool
    ) public view returns (Asset memory) {
        Asset memory asset = pool.getAsset(assetId);
        if (!asset.isActive) {
            revert InactiveAsset(asset.id);
        }

        if (asset.assetType != AssetType.ERC20) {
            revert UnsupportedAsset(asset.id);
        }

        return asset;
    }

    function decodeAsset(
        uint248 pubAsset
    ) public pure returns (uint24 assetId, uint224 value) {
        // Extract first 3 bytes assetId
        assetId = uint24(bytes3(bytes31(pubAsset)));
        // Extract last 28 bytes value
        value = uint224(pubAsset);
    }
}
