// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Spark LP Rewards (usespark.fun/builder).
// Exact-input buys: take token-output share; flush() donates to in-range LPs.

import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

/// @title LpRewards
/// @notice Pulls rewardBps of buy output, then flush() donates pending tokens to LPs.
contract LpRewards is BaseHook, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using SafeCast for uint256;
    using StateLibrary for IPoolManager;

    error NotNativePair();
    error NothingPending();
    error NoLiquidityToReceiveDonation();

    mapping(PoolId => uint256) public pending;

    uint16 public immutable rewardBps;

    constructor(IPoolManager poolManager, uint16 _rewardBps) BaseHook(poolManager) {
        rewardBps = _rewardBps;
    }

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
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal pure override returns (bytes4) {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        return this.afterInitialize.selector;
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        if (!params.zeroForOne || params.amountSpecified >= 0) return (this.afterSwap.selector, 0);

        int128 tokenOut = delta.amount1();
        if (tokenOut <= 0) return (this.afterSwap.selector, 0);

        uint256 reward = (uint256(int256(tokenOut)) * rewardBps) / 10_000;
        if (reward == 0) return (this.afterSwap.selector, 0);

        key.currency1.take(poolManager, address(this), reward, false);
        pending[key.toId()] += reward;

        return (this.afterSwap.selector, reward.toInt128());
    }

    function flush(PoolKey calldata key) external {
        poolManager.unlock(abi.encode(key));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        PoolKey memory key = abi.decode(data, (PoolKey));
        PoolId id = key.toId();
        uint256 amount = pending[id];
        if (amount == 0) revert NothingPending();
        if (poolManager.getLiquidity(id) == 0) revert NoLiquidityToReceiveDonation();

        pending[id] = 0;
        poolManager.donate(key, 0, amount, "");
        key.currency1.settle(poolManager, address(this), amount, false);
        return "";
    }
}
