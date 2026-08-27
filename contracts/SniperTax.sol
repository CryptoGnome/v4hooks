// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Zora launch fee decay (99% → 1% over ~10s).
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

/// @title SniperTax
/// @notice Launch fee decays linearly from startFee to baseFee over duration seconds after init.
contract SniperTax is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    error NotDynamicFee();

    mapping(PoolId => uint256) public launchTime;

    uint24 public immutable startFee;
    uint24 public immutable baseFee;
    uint256 public immutable duration;

    constructor(IPoolManager poolManager, uint24 _startFee, uint24 _baseFee, uint256 _duration) BaseHook(poolManager) {
        startFee = _startFee;
        baseFee = _baseFee;
        duration = _duration;
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
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function feeFor(PoolId poolId) public view returns (uint24) {
        uint256 start = launchTime[poolId];
        if (start == 0) return baseFee;
        uint256 elapsed = block.timestamp - start;
        if (elapsed >= duration) return baseFee;
        uint256 delta = uint256(startFee) - uint256(baseFee);
        return uint24(uint256(baseFee) + (delta * (duration - elapsed)) / duration);
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        launchTime[key.toId()] = block.timestamp;
        return this.afterInitialize.selector;
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 fee = feeFor(key.toId());
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }
}
