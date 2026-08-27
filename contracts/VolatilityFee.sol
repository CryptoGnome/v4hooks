// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Clanker tick-accumulator dynamic fee patterns.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

/// @title VolatilityFee
/// @notice LP fee rises with |currentTick - lastTick| since the previous swap.
contract VolatilityFee is BaseHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using LPFeeLibrary for uint24;

    error NotDynamicFee();

    mapping(PoolId => int24) public lastTick;
    mapping(PoolId => bool) public initialized;

    uint24 public immutable baseFee;
    uint24 public immutable maxFee;
    uint24 public immutable tickFactor;

    constructor(IPoolManager poolManager, uint24 _baseFee, uint24 _maxFee, uint24 _tickFactor) BaseHook(poolManager) {
        baseFee = _baseFee;
        maxFee = _maxFee;
        tickFactor = _tickFactor;
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

    function feeFor(PoolKey calldata key) public view returns (uint24) {
        PoolId id = key.toId();
        if (!initialized[id]) return baseFee;
        int24 prev = lastTick[id];
        (, int24 tick,,) = poolManager.getSlot0(id);
        uint256 move = _absTickDelta(tick, prev);
        uint256 total = uint256(baseFee) + move * uint256(tickFactor);
        if (total > maxFee) return maxFee;
        return uint24(total);
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24 tick) internal override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        PoolId id = key.toId();
        lastTick[id] = tick;
        initialized[id] = true;
        return this.afterInitialize.selector;
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 fee = feeFor(key);
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        (, int24 tick,,) = poolManager.getSlot0(key.toId());
        lastTick[key.toId()] = tick;
        return (this.afterSwap.selector, 0);
    }

    function _absTickDelta(int24 a, int24 b) private pure returns (uint256) {
        int256 d = int256(a) - int256(b);
        return uint256(d >= 0 ? d : -d);
    }
}
