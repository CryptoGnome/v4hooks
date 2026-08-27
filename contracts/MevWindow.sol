// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Clanker post-launch MEV fee window + LP freeze.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

/// @title MevWindow
/// @notice Elevated swap fee + blocked add-liquidity for mevBlocks after pool init.
contract MevWindow is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    error NotDynamicFee();
    error MevWindowActive();

    mapping(PoolId => uint256) public launchBlock;

    uint256 public immutable mevBlocks;
    uint24 public immutable baseFee;
    uint24 public immutable mevFee;

    constructor(IPoolManager poolManager, uint256 _mevBlocks, uint24 _baseFee, uint24 _mevFee) BaseHook(poolManager) {
        mevBlocks = _mevBlocks;
        baseFee = _baseFee;
        mevFee = _mevFee;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: true,
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

    function inMevWindow(PoolId poolId) public view returns (bool) {
        uint256 start = launchBlock[poolId];
        return start != 0 && block.number < start + mevBlocks;
    }

    function feeFor(PoolId poolId) public view returns (uint24) {
        return inMevWindow(poolId) ? mevFee : baseFee;
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        launchBlock[key.toId()] = block.number;
        return this.afterInitialize.selector;
    }

    function _beforeAddLiquidity(address, PoolKey calldata key, ModifyLiquidityParams calldata, bytes calldata)
        internal
        view
        override
        returns (bytes4)
    {
        if (inMevWindow(key.toId())) revert MevWindowActive();
        return this.beforeAddLiquidity.selector;
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
