// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

interface IAdaptorHandler {
    error InvalidOutputValue();

    function handleAdaptor(
        address target,
        uint24[] calldata assetIds,
        uint256[] calldata inValues,
        bytes calldata payload
    ) external payable returns (uint24[] memory, uint256[] memory);
}
