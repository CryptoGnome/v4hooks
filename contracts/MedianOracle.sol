// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Rewrite of saucepoint median-oracles (MIT). Ring buffer of post-swap ticks; median view.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickLower} from "./lib/TickLower.sol";

/// @title MedianOracle
/// @notice afterSwap records floored tick in a fixed ring; medianTick() sorts the window.
contract MedianOracle is BaseHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    struct Window {
        int24[16] samples;
        uint8 index;
        uint8 count;
    }

    mapping(PoolId => Window) public windows;

    constructor(IPoolManager poolManager) BaseHook(poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        PoolId id = key.toId();
        (, int24 tick,,) = poolManager.getSlot0(id);
        int24 sample = TickLower.floor(tick, key.tickSpacing);
        Window storage w = windows[id];
        w.samples[w.index] = sample;
        w.index = uint8((w.index + 1) % 16);
        if (w.count < 16) w.count++;
        return (this.afterSwap.selector, 0);
    }

    function medianTick(PoolId id) public view returns (int24) {
        Window memory w = windows[id];
        uint8 n = w.count;
        if (n == 0) return 0;
        int24[] memory buf = new int24[](n);
        for (uint8 i = 0; i < n; i++) {
            buf[i] = w.samples[i];
        }
        for (uint8 i = 1; i < n; i++) {
            int24 v = buf[i];
            uint8 j = i;
            while (j > 0 && buf[j - 1] > v) {
                buf[j] = buf[j - 1];
                unchecked {
                    j--;
                }
            }
            buf[j] = v;
        }
        return buf[n / 2];
    }
}
