// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {PubAsset} from "../libraries/ShieldedTransaction.sol";

interface IAdaptorHandler {
    error InvalidOutputValue();
    error OnlyPoolCanCall();
    error PoolNotSet();

    function handleAdaptor(
        address target,
        PubAsset[] calldata inPubAssets,
        bytes calldata payload
    ) external payable returns (PubAsset[] memory outPubAssets);
}
