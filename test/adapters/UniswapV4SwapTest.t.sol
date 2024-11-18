// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {UniswapV4SwapTest} from "src/adaptors/uniswap-v4/UniswapV4SwapTest.sol";
import {Test} from "forge-std/Test.sol";

contract UniswapV4SwapTestTest is Test {
    UniswapV4SwapTest uniswapV4SwapTest;
    address token0 = 0x4200000000000000000000000000000000000006;

    function setUp() external {
        uniswapV4SwapTest = new UniswapV4SwapTest();
    }

    function testV4SwapThroughPoolSwapTest() external {
        deal(token0, address(uniswapV4SwapTest), 1 ether);
        uniswapV4SwapTest.handleAssets();
    }
}
