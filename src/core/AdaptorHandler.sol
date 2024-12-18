// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IAdaptor} from "../interfaces/IAdaptor.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Params, MemoParams, ShieldedTransaction, ShieldedTransactionType} from "../libraries/ShieldedTransaction.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";
import {PubAsset} from "../libraries/ShieldedTransaction.sol";

contract AdaptorHandler is IAdaptorHandler, Ownable {
    using SafeERC20 for IERC20;

    mapping(uint256 txHash => ShieldedTransaction) public nonAtomicTxs;
    address labyrinthPool;

    constructor() Ownable(msg.sender) {}

    function setPool(address pool) external onlyOwner {
        labyrinthPool = pool;
    }

    function handleAdaptor(
        ShieldedTransaction memory stx,
        uint256 txHash,
        address target,
        PubAsset[] calldata pubAssets,
        bytes calldata targetPayload
    ) external payable returns (PubAsset[] memory) {
        uint24[] memory inAssetIds = new uint24[](pubAssets.length);
        uint256[] memory inValues = new uint256[](pubAssets.length);
        for (uint8 i = 0; i < pubAssets.length; ) {
            inAssetIds[i] = pubAssets[i].id;
            inValues[i] = pubAssets[i].value;

            unchecked {
                ++i;
            }
        }

        (bool success, bytes memory res) = target.delegatecall(
            abi.encodeCall(
                IAdaptor.handleAssets,
                (inAssetIds, inValues, targetPayload)
            )
        );

        require(success, string(res));

        /// @todo rename outAssetIds, outValues => refundedAssetIds, refundedValues
        (uint24[] memory outAssetIds, uint256[] memory outValues) = abi.decode(
            res,
            (uint24[], uint256[])
        );

        // non-atomic tx
        if (outAssetIds.length == 0) {
            /**
            NonAtomicTx memory nonAtomicTxData = NonAtomicTx({
                refundAddress: refundAddress,
                params: stxParams,
                memoParams: stxMemoParams,
                refundedAssets: new PubAssets[](0)
            });
            nonAtomicTxs[txHash] = nonAtomicTxData;
             */

            nonAtomicTxs[txHash] = stx;
            return (new PubAsset[](0));
        }

        PubAsset[] memory outPubAssets = _approveAndReturnPubAssets(
            outAssetIds,
            outValues
        );

        return outPubAssets;
    }

    function completeNonAtomicTx(
        uint256 txHash,
        uint24[] memory outAssetIds,
        uint256[] memory outValues
    ) external payable {
        PubAsset[] memory outPubAssets = _approveAndReturnPubAssets(
            outAssetIds,
            outValues
        );

        IPool(labyrinthPool).completeNonAtomicTx(
            nonAtomicTxs[txHash],
            outPubAssets
        );

        delete nonAtomicTxs[txHash];
    }

    function nonAtomicTxExists(uint256 txHash) external view returns (bool) {
        if (
            nonAtomicTxs[txHash].txType == ShieldedTransactionType.CALL_ADAPTOR
        ) {
            return true;
        }
        return false;
    }

    /// @notice `outAssetIds` and `outValues` are approved to the Pool. Also `outAssetIds` and `outValues` are returned as struct PubAssets.
    function _approveAndReturnPubAssets(
        uint24[] memory outAssetIds,
        uint256[] memory outValues
    ) internal returns (PubAsset[] memory) {
        Asset memory asset;
        uint256 assetBalance;

        PubAsset[] memory outPubAssets = new PubAsset[](outAssetIds.length);
        for (uint8 i = 0; i < outAssetIds.length; ) {
            asset = IPool(labyrinthPool).getAsset(outAssetIds[i]);

            if (!asset.isActive) {
                revert IPool.InactiveAsset(asset.id);
            }

            if (outValues[i] > type(uint224).max) {
                revert OutputValueExceedsUint224();
            }

            assetBalance = IERC20(asset.assetAddress).balanceOf(address(this));

            // Not checking for equality because of it might fail if somehow this contract is sent tokens from other sources apart from doing shielded transactions.
            if (assetBalance < outValues[i]) {
                revert InvalidOutputValue();
            }

            IERC20(asset.assetAddress).forceApprove(
                labyrinthPool,
                outValues[i]
            );

            outPubAssets[i] = PubAsset(outAssetIds[i], uint224(outValues[i]));

            unchecked {
                ++i;
            }
        }

        return outPubAssets;
    }

    // Allow Lido/RocketPool adaptor to receive unwrapped Ether for staking
    receive() external payable {}
}
