// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {UniswapV4} from "src/adaptors/uniswap-v4/UniswapV4.sol";
import {Test} from "forge-std/Test.sol";

contract UniswapV4Test is Test {
    UniswapV4 uniswapV4;
    address token0 = 0x4200000000000000000000000000000000000006;

    function setUp() external {
        uniswapV4 = new UniswapV4();
    }

    function testV4SwapThroughPoolManager() external {
        deal(token0, address(uniswapV4), 1 ether);
        uniswapV4.handleAssets();
    }
}
