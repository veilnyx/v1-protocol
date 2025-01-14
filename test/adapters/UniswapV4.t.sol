// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {UniswapV4} from "src/adaptors/uniswap-v4/UniswapV4.sol";
import {TickMath} from "@uniswapV4/src/libraries/TickMath.sol";
import {PoolManager} from "@uniswapV4/src/PoolManager.sol";
import {Deployers} from "@uniswapV4/test/utils/Deployers.sol";
import {Constants} from "@uniswapV4/test/utils/Constants.sol";
import {PoolKey} from "@uniswapV4/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswapV4/src/types/Currency.sol";
import {PoolEmptyUnlockTest} from "@uniswapV4/src/test/PoolEmptyUnlockTest.sol";
import {IHooks} from "@uniswapV4/src/interfaces/IHooks.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

contract UniswapV4Test is Deployers {
    using CurrencyLibrary for Currency;

    UniswapV4 uniswapV4;
    uint160 sqrtPriceX96 = Constants.SQRT_PRICE_1_1;

    function setUp() external {
        initializeManagerRoutersAndPoolsWithLiq(IHooks(address(0)));
        uniswapV4 = new UniswapV4();
    }

    function test_unlock_EmitsCorrectId() public {
        PoolEmptyUnlockTest emptyUnlockTest = new PoolEmptyUnlockTest(manager);

        vm.expectEmit(false, false, false, true);
        emit PoolEmptyUnlockTest.UnlockCallback();
        emptyUnlockTest.unlock();
    }

    function testV4Swap() external {
        // transfer 1e18 of currency0 to UniswapV4 contract to swap
        currency0.transfer(address(uniswapV4), 1 ether);

        uniswapV4.swap(manager, currency0, currency1);
    }

    // function testGetQuote() external {
    //     (uint256 amountOut, uint256 gasEstimate) = uniswapV4.getQuote(
    //         key,
    //         true
    //     );
    //     console2.log("quote amtOut:", amountOut);
    // }

    // function testV4SwapThroughPoolManager() external {
    //     deal(token0, address(uniswapV4), 1 ether);
    //     uniswapV4.handleAssets();
    // }
}
