// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {PubAsset} from "../libraries/ShieldedTransaction.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";

interface IAdaptorHandler {
    error InvalidOutputValue();
    error OutputValueExceedsUint224();

    function handleAdaptor(
        ShieldedTransaction calldata stx,
        uint256 txHash,
        address target,
        PubAsset[] calldata inPubAssets,
        bytes calldata payload
    ) external payable returns (PubAsset[] memory outPubAssets);

    function completeNonAtomicTx(
        uint256 txHash,
        uint24[] memory outAssetIds,
        uint256[] memory outValues
    ) external payable;

    function nonAtomicTxExists(uint256 txHash) external view returns (bool);
}
