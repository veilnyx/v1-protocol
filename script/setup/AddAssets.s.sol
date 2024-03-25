// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseScript} from "../BaseScript.sol";
import {Pool} from "src/core/Pool.sol";
import {AssetType} from "src/libraries/DataTypes.sol";

contract AddAssets is BaseScript {
    function run() external broadcast {
        address poolProxy = _getContract("PoolProxy");
        Pool pool = Pool(poolProxy);

        AssetType[] memory assetTypes = new AssetType[](1);
        address[] memory assetAddresses = new address[](1);

        assetTypes[0] = AssetType.ERC20;
        assetAddresses[0] = address(0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889);

        pool.addAssets(assetTypes, assetAddresses);
    }
}
