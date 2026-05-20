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

        assetAddresses[0] = address(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af);

        pool.addAssets(assetType, assetAddresses);
    }
}
