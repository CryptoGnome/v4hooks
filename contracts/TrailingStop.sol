// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Inspired by Hookathon C1 Trailing Hook. Peak-tick trailing stop per trader.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickLower} from "./lib/TickLower.sol";

/// @title TrailingStop
/// @notice Tracks peak tick per trader; sells hitting trail distance pay TRAIL_FEE (teaching stand-in for market exit).
contract TrailingStop is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error NotDynamicFee();

    struct Trail {
        int24 peakTick;
        bool active;
    }

    mapping(PoolId => mapping(address => Trail)) public trails;

    int24 public immutable trailDistance;
    uint24 public immutable trailFee;
    uint24 public immutable baseFee;

    constructor(IPoolManager poolManager, int24 _trailDistance, uint24 _trailFee, uint24 _baseFee)
        BaseHook(poolManager)
    {
        trailDistance = _trailDistance;
        trailFee = _trailFee;
        baseFee = _baseFee;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function traderOf(address sender, bytes calldata hookData) public pure returns (address) {
        if (hookData.length >= 32) return abi.decode(hookData, (address));
        return sender;
    }

    function armTrail(PoolKey calldata key, address trader) external {
        PoolId id = key.toId();
        (, int24 tick,,) = poolManager.getSlot0(id);
        trails[id][trader] = Trail({peakTick: TickLower.floor(tick, key.tickSpacing), active: true});
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal pure override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        return this.afterInitialize.selector;
    }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address trader = traderOf(sender, hookData);
        PoolId id = key.toId();
        Trail memory t = trails[id][trader];
        uint24 fee = baseFee;

        if (t.active && !params.zeroForOne) {
            (, int24 tick,,) = poolManager.getSlot0(id);
            int24 current = TickLower.floor(tick, key.tickSpacing);
            if (current <= t.peakTick - trailDistance) fee = trailFee;
        }

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        if (params.zeroForOne) {
            address trader = traderOf(sender, hookData);
            PoolId id = key.toId();
            (, int24 tick,,) = poolManager.getSlot0(id);
            int24 current = TickLower.floor(tick, key.tickSpacing);
            Trail storage t = trails[id][trader];
            if (!t.active) {
                t.active = true;
                t.peakTick = current;
            } else if (current > t.peakTick) {
                t.peakTick = current;
            }
        }
        return (this.afterSwap.selector, 0);
    }
}
