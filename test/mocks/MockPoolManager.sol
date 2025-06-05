// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract MockPoolManager is IPoolManager {
    mapping(PoolId => int24) public ticks;
    
    function toId(PoolKey memory key) internal pure returns (PoolId) {
        return PoolId.wrap(keccak256(abi.encode(key)));
    }

    // Override the hook validation function
    function isValidHookAddress(IHooks hooks) internal pure returns (bool) {
        return true;
    }

    function initialize(PoolKey memory key, uint160) external override returns (int24) {
        
        PoolId id = toId(key);
        ticks[id] = 0;
        
        if (address(key.hooks) != address(0)) {
            try key.hooks.afterInitialize(msg.sender, key, uint160(1 << 96), 0) returns (bytes4) {} catch {}
        }
        
        return 0;
    }

    function swap(PoolKey memory key, SwapParams memory params, bytes calldata) 
        external override returns (BalanceDelta) 
    {
        int128 amount0 = params.zeroForOne ? -int128(uint128(uint256(-params.amountSpecified))) : int128(uint128(uint256(-params.amountSpecified)/2));
        int128 amount1 = params.zeroForOne ? int128(uint128(uint256(-params.amountSpecified)/2)) : -int128(uint128(uint256(-params.amountSpecified)));
        
        BalanceDelta delta = BalanceDelta.wrap(int256(amount0));
        
        if (address(key.hooks) != address(0)) {
            try key.hooks.afterSwap(msg.sender, key, params, delta, "") returns (bytes4, int128) {} catch {}
        }
        
        return delta;
    }
    
    function getSlot0(PoolId id) external view returns (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 swapFee) {
        return (uint160(1 << 96), ticks[id], 0, 0);
    }

    function modifyLiquidity(PoolKey memory, ModifyLiquidityParams memory, bytes calldata) external pure override returns (BalanceDelta, BalanceDelta) { 
        return (BalanceDelta.wrap(0), BalanceDelta.wrap(0)); 
    }
    
    function donate(PoolKey memory, uint256, uint256, bytes calldata) external pure override returns (BalanceDelta) { 
        return BalanceDelta.wrap(0); 
    }
    
    function sync(Currency) external pure override {}
    
    function take(Currency currency, address to, uint256 amount) external override { 
        currency.transfer(to, amount);
    }
    
    function settle() external payable override returns (uint256) { return 0; }
    function settleFor(address) external payable override returns (uint256) { return 0; }
    function clear(Currency, uint256) external pure override {}
    function mint(address, uint256, uint256) external pure override {}
    function burn(address, uint256, uint256) external pure override {}
    function updateDynamicLPFee(PoolKey memory, uint24) external pure override {}

    function collectProtocolFees(address, Currency, uint256) external pure override returns (uint256) { return 0; }
    function protocolFeeController() external view override returns (address) { return address(0); }
    function protocolFeesAccrued(Currency) external view override returns (uint256) { return 0; }
    
    function setProtocolFee(PoolKey memory key, uint24 newProtocolFee) external pure override {}
    
    function setProtocolFeeController(address) external pure override {}

    function balanceOf(address, uint256) external view override returns (uint256) { return 0; }
    function allowance(address, address, uint256) external view override returns (uint256) { return 0; }
    function approve(address, uint256, uint256) external pure override returns (bool) { return true; }
    function isOperator(address, address) external view override returns (bool) { return false; }
    function setOperator(address, bool) external pure override returns (bool) { return true; }
    function transfer(address, uint256, uint256) external pure override returns (bool) { return true; }
    function transferFrom(address, address, uint256, uint256) external pure override returns (bool) { return true; }

    function extsload(bytes32) external view override returns (bytes32) { return bytes32(0); }
    function extsload(bytes32[] calldata) external view override returns (bytes32[] memory) { return new bytes32[](0); }
    
    function extsload(bytes32 startSlot, uint256 nSlots) external view override returns (bytes32[] memory) { 
        return new bytes32[](0); 
    }
    
    function exttload(bytes32) external view override returns (bytes32) { return bytes32(0); }
    
    function exttload(bytes32[] calldata slots) external view override returns (bytes32[] memory) { 
        return new bytes32[](0); 
    }
    
    function exttsload(bytes32 slot) external view returns (bytes32) { return bytes32(0); }
    
    function unlock(bytes calldata) external pure override returns (bytes memory) { return bytes(""); }
}
