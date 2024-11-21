// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// PoolSwapTest swapRouter = PoolSwapTest(0x01);
import {PoolSwapTest} from "@uniswapV4/src/test/PoolSwapTest.sol";
import {IPoolManager} from "@uniswapV4/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswapV4/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswapV4/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswapV4/src/types/Currency.sol";
import {CurrencySettler} from "@uniswapV4/test/utils/CurrencySettler.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "@uniswapV4/src/types/BalanceDelta.sol";
import {IV4Quoter} from "./IV4Quoter.sol";
import {IUnlockCallback} from "./IUnlockCallback.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

contract UniswapV4 is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;

    error UnauthorizedSender(address);

    /// @dev The minimum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_PRICE =
        1461446703485210103287273052203988822378723970342;

    // slippage tolerance to allow for unlimited price impact
    uint160 public constant MIN_PRICE_LIMIT = MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = MAX_SQRT_PRICE - 1;

    IPoolManager poolManager;
    Currency currency0;
    Currency currency1;

    ////////////////////////////
    //// Ext. Functions ////////
    ////////////////////////////

    function swap(
        IPoolManager poolManager_,
        Currency currency0_,
        Currency currency1_
    ) external returns (BalanceDelta delta) {
        poolManager = poolManager_;
        currency0 = currency0_;
        currency1 = currency1_;

        address hookAddr = address(0);
        bool zeroForOne = true;
        bytes memory hookData = ""; // no hook data on the hookless pool
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddr)
        });

        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: 1 ether,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });

        bytes memory swapParamsCalldata = abi.encode(
            poolKey,
            swapParams,
            hookData
        );

        bytes memory encodedBalDelta = poolManager.unlock(swapParamsCalldata);
        BalanceDelta returnedBalDelta = abi.decode(
            encodedBalDelta,
            (BalanceDelta)
        );

        int128 amt0 = returnedBalDelta.amount0();
        int128 amt1 = returnedBalDelta.amount1();

        console2.log("amt0:", amt0);
        console2.log("amt1:", amt1);

        return returnedBalDelta;
    }

    function unlockCallback(
        bytes memory swapParamsCalldata
    ) external returns (bytes memory) {
        console2.log("Inside unlockCallback()");
        if (msg.sender != address(poolManager)) {
            revert UnauthorizedSender(msg.sender);
        }

        (
            PoolKey memory key,
            IPoolManager.SwapParams memory params,
            bytes memory hookData
        ) = abi.decode(
                swapParamsCalldata,
                (PoolKey, IPoolManager.SwapParams, bytes)
            );

        BalanceDelta balDelta = poolManager.swap(key, params, hookData);

        int256 deltaAfter0 = balDelta.amount0();
        int256 deltaAfter1 = balDelta.amount1();

        console2.log("Swap done!");
        console2.log("deltaAfter0:", deltaAfter0);
        console2.log("deltaAfter1:", deltaAfter1);

        // Settling with PoolManager
        if (deltaAfter0 < 0) {
            console2.log("Transferring currency0 to poolManager");
            poolManager.sync(currency0);
            currency0.transfer(address(poolManager), uint256(deltaAfter0 * -1));
            poolManager.settle();
        }
        if (deltaAfter1 < 0) {
            poolManager.sync(currency1);
            currency1.transfer(address(poolManager), uint256(deltaAfter1 * -1));
            poolManager.settle();
        }

        if (deltaAfter0 > 0) {
            poolManager.take(currency0, address(this), uint256(deltaAfter0));
        }
        if (deltaAfter1 > 0) {
            console2.log("Taking currency1 from poolManager");
            poolManager.take(currency1, address(this), uint256(deltaAfter1));
        }

        bytes memory encodedBalDelta = abi.encode(balDelta);
        return encodedBalDelta;
    }
}
