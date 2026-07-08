// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

struct AssetAmount {
    uint24 assetId;
    uint256 value;
}

abstract contract IAdaptor {
    function handleAssets(
        AssetAmount[] calldata inAssets,
        bytes calldata payload
    ) external payable virtual returns (AssetAmount[] memory outAssets);
}
