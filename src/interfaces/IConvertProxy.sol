// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
import {Asset, AssetType} from "../libraries/DataTypes.sol";

abstract contract IConvertProxy {
    function convert(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata payload
    )
        external
        payable
        virtual
        returns (uint24[] memory outAssetIds, uint256[] memory outValues);
}
