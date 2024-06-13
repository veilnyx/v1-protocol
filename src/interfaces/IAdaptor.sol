// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Asset, AssetType} from "../libraries/Asset.sol";

abstract contract IAdaptor {
    function adaptorConnect(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata payload
    )
        external
        payable
        virtual
        returns (uint24[] memory outAssetIds, uint256[] memory outValues);
}
