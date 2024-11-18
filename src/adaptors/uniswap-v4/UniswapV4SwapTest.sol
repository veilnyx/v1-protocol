// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// PoolSwapTest swapRouter = PoolSwapTest(0x01);
import {PoolKey, Currency, IHooks} from "./PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "./BalanceDeltaLibrary.sol";
import {IPoolSwapTest} from "./IPoolSwapTest.sol";
import {IUnlockCallback} from "./IUnlockCallback.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

contract UniswapV4SwapTest {
    using BalanceDeltaLibrary for BalanceDelta;
    /// @dev The minimum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_PRICE =
        1461446703485210103287273052203988822378723970342;

    // slippage tolerance to allow for unlimited price impact
    uint160 public constant MIN_PRICE_LIMIT = MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = MAX_SQRT_PRICE - 1;

    // UNIChain Addresses
    address poolSwapTestAddr = 0xe437355299114d35Ffcbc0c39e163B24A8E9cBf1;
    address token0 = 0x4200000000000000000000000000000000000006; // WETH
    address token1 = 0x31d0220469e10c4E71834a79b1f276d740d3768F; // USDC
    address hookAddr = address(0);
    IPoolSwapTest poolSwapTest = IPoolSwapTest(poolSwapTestAddr);

    PoolKey poolKey =
        PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddr)
        });

    // ------------------------------------ //
    // Swap exactly 1e18 of token0 into token1
    // ------------------------------------- //
    bool zeroForOne = true;
    IPoolSwapTest.SwapParams swapParams =
        IPoolSwapTest.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

    function handleAssets() external returns (BalanceDelta) {
        bytes memory hookData = new bytes(0); // no hook data on the hookless pool

        // in v4, users have the option to receieve native ERC20s or wrapped ERC6909 tokens
        // here, we'll take the ERC20s
        IPoolSwapTest.TestSettings memory testSettings =
            IPoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        IERC20(token0).approve(address(poolSwapTest), 1 ether);
        BalanceDelta returnedBalDelta = poolSwapTest.swap(poolKey, swapParams, testSettings, hookData);

        return returnedBalDelta;
    }
}
