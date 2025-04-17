// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {Pool} from "src/core/Pool.sol";
import {AssetType} from "src/libraries/Asset.sol";

contract AddAssets is BaseScript {
    function run() external broadcast {
        address poolProxy = _getContract("PoolProxy");
        Pool pool = Pool(poolProxy);

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](1);
        uint8[] memory assetsPrecision = new uint8[](1);

        assetAddresses[0] = address(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889);
        assetsPrecision[1] = 18;

        pool.addAssets(assetType, assetAddresses, assetsPrecision);
    }
}
