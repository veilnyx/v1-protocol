// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// PoolSwapTest swapRouter = PoolSwapTest(0x01);
import {PoolKey, Currency, IHooks} from "./PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "./BalanceDeltaLibrary.sol";
import {IPoolManager} from "./IPoolManager.sol";
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

    // UNIChain Addresses
    address poolManagerAddr = 0xC81462Fec8B23319F288047f8A03A57682a35C1A;
    address token0 = 0x4200000000000000000000000000000000000006; // WETH
    address token1 = 0x31d0220469e10c4E71834a79b1f276d740d3768F; // USDC
    address hookAddr = address(0);
    IPoolManager poolManager = IPoolManager(poolManagerAddr);

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
    IPoolManager.SwapParams swapParams =
        IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

    function handleAssets() external returns (BalanceDelta) {
        // approve tokens to the pool manager
        IERC20(token0).approve(address(poolManager), 1 ether);
        bytes memory hookData = new bytes(0); // no hook data on the hookless pool

        // call PoolManager.unlock(bytes calldata data)
        bytes memory swapParamsCalldata = abi.encode(
            poolKey,
            swapParams,
            hookData
        );

        // if (!poolManager.isUnlocked()) {
        bytes memory encodedBalDelta = poolManager.unlock(swapParamsCalldata);
        // }

        BalanceDelta returnedBalDelta = abi.decode(
            encodedBalDelta,
            (BalanceDelta)
        );
        return returnedBalDelta;
    }

    function unlockCallback(
        bytes memory swapParamsCalldata
    ) external returns (bytes memory) {
        console2.log("Inside unlockCallback()");
        if(msg.sender != poolManagerAddr) {
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
        int128 amt0 = balDelta.amount0();
        int128 amt1 = balDelta.amount1();

        bytes memory encodedBalDelta = abi.encode(balDelta);
        return encodedBalDelta;
    }
}
