// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {PubAsset} from "../libraries/ShieldedTransaction.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";

interface IAdaptorHandler {
    error InvalidOutputValue();
    error NonAtomicTxNotFound(uint256);

    function handleAdaptor(
        ShieldedTransaction calldata stx,
        uint256 txHash,
        address target,
        PubAsset[] calldata inPubAssets,
        bytes calldata payload
    ) external payable returns (PubAsset[] memory outPubAssets);
}
