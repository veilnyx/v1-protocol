// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../../BaseScript.sol";
import {UniswapV3Adapter} from "src/adaptors/uniswap-v3/UniswapV3Adapter.sol";

contract UniswapV3AdaptorDeploy is BaseScript {
    function run() external broadcast returns (UniswapV3Adapter) {
        address poolProxy = _getContract("PoolProxy");
        address uniswapRouter02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

        UniswapV3Adapter uniswapV3Adapter = new UniswapV3Adapter(
            uniswapRouter02,
            poolProxy
        );
        return uniswapV3Adapter;
    }
}
