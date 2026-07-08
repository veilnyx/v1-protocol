// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {PubAsset} from "../libraries/ShieldedTransactionLogic.sol";

interface IAdaptorHandler {
    error InvalidOutputValue(
        uint24 assetId,
        uint256 expectedMin,
        uint256 actualBalance
    );
    error OnlyPoolCanCall();
    error PoolNotSet();

    function handleAdaptor(
        address target,
        PubAsset[] calldata inPubAssets,
        bytes calldata payload
    ) external payable returns (PubAsset[] memory outPubAssets);
}
