// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Inspired by atj3097/buyback-hook. When tick is below threshold, treasury ETH buys token via unlock swap.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickLower} from "./lib/TickLower.sol";

/// @title Buyback
/// @notice Native pair: fund hook with ETH; buyback() market-buys when tick <= thresholdTick.
contract Buyback is BaseHook, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;

    error NotNativePair();
    error PriceAboveThreshold();
    error NoTreasury();

    mapping(PoolId => int24) public thresholdTick;

    constructor(IPoolManager poolManager) BaseHook(poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    receive() external payable {}

    function setThreshold(PoolKey calldata key, int24 tick) external {
        thresholdTick[key.toId()] = tick;
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal pure override returns (bytes4) {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        return this.afterInitialize.selector;
    }

    function buyback(PoolKey calldata key, uint256 ethAmount) external {
        PoolId id = key.toId();
        int24 thresh = thresholdTick[id];
        (, int24 tick,,) = poolManager.getSlot0(id);
        if (TickLower.floor(tick, key.tickSpacing) > thresh) revert PriceAboveThreshold();
        if (ethAmount == 0 || address(this).balance < ethAmount) revert NoTreasury();

        SwapParams memory p =
            SwapParams({zeroForOne: true, amountSpecified: -int256(ethAmount), sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1});
        poolManager.unlock(abi.encode(key, p));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        (PoolKey memory key, SwapParams memory params) = abi.decode(data, (PoolKey, SwapParams));
        BalanceDelta delta = poolManager.swap(key, params, "");
        if (delta.amount0() < 0) {
            key.currency0.settle(poolManager, address(this), uint256(uint128(-delta.amount0())), false);
        }
        if (delta.amount1() > 0) {
            key.currency1.take(poolManager, address(this), uint256(uint128(delta.amount1())), false);
        }
        return "";
    }
}
