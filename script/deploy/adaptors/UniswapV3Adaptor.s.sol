// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../../BaseScript.sol";
import {UniswapV3Adapter} from "src/adaptors/uniswap-v3/UniswapV3Adapter.sol";

contract UniswapV3AdaptorDeploy is BaseScript {
    function run() external broadcast returns(UniswapV3Adapter) {
        address poolProxy = _getContract("PoolProxy");
        address uniswapRouter02 = _config.uniswapSwapRouter02();

        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter(uniswapRouter02, poolProxy);
        return uniswapV3Adapter;
    }
}
