// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {Pool} from "src/core/Pool.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract AddAssets is BaseScript {
    function run() external broadcast {
        address poolProxy = _getContract("PoolProxy");
        Pool pool = Pool(payable(poolProxy));

        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](1);
        uint8[] memory precisions = new uint8[](1);

        assetAddresses[0] = address(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af);
        precisions[0] = 18;

        AggregatorV3Interface[]
            memory usdPriceFeeds = new AggregatorV3Interface[](1);
        // usdPriceFeeds[0] = AggregatorV3Interface(0x...); // set Chainlink feed if available

        pool.addAssets(assetType, assetAddresses, precisions, usdPriceFeeds);
    }
}
