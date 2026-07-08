// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {Pool} from "src/core/Pool.sol";
import {AssetType, AssetInitParams} from "src/libraries/AssetLogic.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract AddAssets is BaseScript {
    function run() external broadcast {
        address poolProxy = _getContract("PoolProxy");
        Pool pool = Pool(payable(poolProxy));

        AssetInitParams[] memory params = new AssetInitParams[](1);
        params[0] = AssetInitParams({
            assetAddress: address(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af),
            precision: 18,
            usdPriceFeed: AggregatorV3Interface(address(0)) // set Chainlink feed if available
        });

        pool.addAssets(AssetType.ERC20, params);
    }
}
