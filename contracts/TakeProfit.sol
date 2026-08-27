// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Rewrite of LearnWeb3 take-profits hook. Mirror of StopLoss — fills on upward tick crosses.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickLower} from "./lib/TickLower.sol";

/// @title TakeProfit
/// @notice Registers take-profit size at a tick; afterSwap fills when price crosses up through it.
contract TakeProfit is BaseHook, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;

    event TakeProfitFilled(PoolId indexed poolId, int24 tick, uint256 amount);

    mapping(PoolId => int24) public tickLowerLast;
    mapping(PoolId => mapping(int24 => uint256)) public profitAtTick;

    uint160 internal constant MIN_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 internal constant MAX_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

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
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function registerProfit(PoolKey calldata key, int24 tick, uint256 amount) external {
        profitAtTick[key.toId()][tick] += amount;
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24 tick)
        internal
        override
        returns (bytes4)
    {
        tickLowerLast[key.toId()] = TickLower.floor(tick, key.tickSpacing);
        return this.afterInitialize.selector;
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        PoolId id = key.toId();
        int24 prev = tickLowerLast[id];
        (, int24 tick,,) = poolManager.getSlot0(id);
        int24 current = TickLower.floor(tick, key.tickSpacing);

        if (current > prev) {
            int24 t = prev + key.tickSpacing;
            while (t <= current) {
                uint256 amt = profitAtTick[id][t];
                if (amt != 0) {
                    _fill(key, t, amt);
                    profitAtTick[id][t] = 0;
                }
                unchecked {
                    t += key.tickSpacing;
                }
            }
        }

        tickLowerLast[id] = current;
        return (this.afterSwap.selector, 0);
    }

    function _fill(PoolKey calldata key, int24 tick, uint256 amount) internal {
        SwapParams memory p =
            SwapParams({zeroForOne: false, amountSpecified: -int256(amount), sqrtPriceLimitX96: MAX_LIMIT});
        poolManager.unlock(abi.encode(key, p, tick));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        (PoolKey memory key, SwapParams memory params, int24 tick) = abi.decode(data, (PoolKey, SwapParams, int24));
        BalanceDelta delta = poolManager.swap(key, params, "");
        if (!params.zeroForOne) {
            if (delta.amount1() < 0) {
                key.currency1.settle(poolManager, address(this), uint256(uint128(-delta.amount1())), false);
            }
            if (delta.amount0() > 0) {
                key.currency0.take(poolManager, address(this), uint256(uint128(delta.amount0())), false);
            }
        }
        emit TakeProfitFilled(key.toId(), tick, uint256(-params.amountSpecified));
        return "";
    }
}
