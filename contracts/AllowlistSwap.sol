// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Uniswap Permissioned Pools allowlist gate.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/// @title AllowlistSwap
/// @notice Gate address sets per-pool swap allowlist; beforeSwap reverts for unlisted traders.
contract AllowlistSwap is BaseHook {
    using PoolIdLibrary for PoolKey;

    error Unauthorized();
    error NotGate();

    address public immutable gate;
    mapping(PoolId => mapping(address => bool)) public allowed;

    constructor(IPoolManager poolManager, address _gate) BaseHook(poolManager) {
        gate = _gate;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
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

    function setAllowed(PoolId poolId, address trader, bool ok) external {
        if (msg.sender != gate) revert NotGate();
        allowed[poolId][trader] = ok;
    }

    function traderOf(address sender, bytes calldata hookData) public pure returns (address) {
        if (hookData.length >= 32) return abi.decode(hookData, (address));
        return sender;
    }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata, bytes calldata hookData)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address trader = traderOf(sender, hookData);
        if (!allowed[key.toId()][trader]) revert Unauthorized();
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
}
