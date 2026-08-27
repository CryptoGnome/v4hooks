// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/// @title LiquidityLock
/// @notice afterAddLiquidity sets unlock time; beforeRemoveLiquidity reverts until then.
contract LiquidityLock is BaseHook {
    using PoolIdLibrary for PoolKey;

    error StillLocked(uint256 unlockTime);

    mapping(PoolId => mapping(address => uint256)) public unlockTime;

    uint256 public immutable lockDuration;

    constructor(IPoolManager poolManager, uint256 _lockDuration) BaseHook(poolManager) {
        lockDuration = _lockDuration;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
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

    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        if (params.liquidityDelta > 0) {
            unlockTime[key.toId()][sender] = block.timestamp + lockDuration;
        }
        return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function _beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) internal view override returns (bytes4) {
        uint256 unlock = unlockTime[key.toId()][sender];
        if (unlock != 0 && block.timestamp < unlock) revert StillLocked(unlock);
        return this.beforeRemoveLiquidity.selector;
    }
}
