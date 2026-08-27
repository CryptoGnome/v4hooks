// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Uniswap DualPoolHook JIT lifecycle + vault skim.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";

/// @title JitVault
/// @notice JIT lock blocks LP ops during a swap; optional output skim accrues to vault balances.
contract JitVault is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using SafeCast for uint256;

    error JitInProgress();

    mapping(PoolId => bool) public jitActive;
    mapping(PoolId => uint256) public vault0;
    mapping(PoolId => uint256) public vault1;

    uint16 public immutable skimBps;

    constructor(IPoolManager poolManager, uint16 _skimBps) BaseHook(poolManager) {
        skimBps = _skimBps;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4)
    {
        if (jitActive[key.toId()]) revert JitInProgress();
        return this.beforeAddLiquidity.selector;
    }

    function _beforeRemoveLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4)
    {
        if (jitActive[key.toId()]) revert JitInProgress();
        return this.beforeRemoveLiquidity.selector;
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        jitActive[key.toId()] = true;
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        PoolId id = key.toId();
        jitActive[id] = false;

        int128 out = params.zeroForOne ? delta.amount1() : delta.amount0();
        if (out <= 0 || skimBps == 0) return (this.afterSwap.selector, 0);

        uint256 skim = (uint256(int256(out)) * skimBps) / 10_000;
        if (skim == 0) return (this.afterSwap.selector, 0);

        if (params.zeroForOne) {
            key.currency1.take(poolManager, address(this), skim, false);
            vault1[id] += skim;
        } else {
            key.currency0.take(poolManager, address(this), skim, false);
            vault0[id] += skim;
        }
        return (this.afterSwap.selector, skim.toInt128());
    }
}
