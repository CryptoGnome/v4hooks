// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Inspired by FairTrade (ETHNYC) and SafeSwap. Sell cooldown + escalating sell fee.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

/// @title SellGuard
/// @notice Native-pair sells: cooldown between sells and fee ramp for rapid sells.
contract SellGuard is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    error NotNativePair();
    error NotDynamicFee();
    error SellCooldown();

    mapping(PoolId => mapping(address => uint256)) public lastSellBlock;
    mapping(PoolId => mapping(address => uint256)) public windowStartBlock;
    mapping(PoolId => mapping(address => uint256)) public sellsInWindow;

    uint256 public immutable cooldownBlocks;
    uint256 public immutable windowBlocks;
    uint24 public immutable baseFee;
    uint24 public immutable rampFee;

    constructor(IPoolManager poolManager, uint256 _cooldownBlocks, uint256 _windowBlocks, uint24 _baseFee, uint24 _rampFee)
        BaseHook(poolManager)
    {
        cooldownBlocks = _cooldownBlocks;
        windowBlocks = _windowBlocks;
        baseFee = _baseFee;
        rampFee = _rampFee;
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

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal pure override returns (bytes4) {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        return this.afterInitialize.selector;
    }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        uint24 fee = baseFee;
        if (!params.zeroForOne) {
            address trader = traderOf(sender, hookData);
            PoolId id = key.toId();
            uint256 last = lastSellBlock[id][trader];
            if (last != 0 && block.number < last + cooldownBlocks) revert SellCooldown();
            if (sellsInWindow[id][trader] >= 1) fee = rampFee;
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
        if (!params.zeroForOne) {
            address trader = traderOf(sender, hookData);
            PoolId id = key.toId();
            lastSellBlock[id][trader] = block.number;
            uint256 ws = windowStartBlock[id][trader];
            if (ws == 0 || block.number >= ws + windowBlocks) {
                windowStartBlock[id][trader] = block.number;
                sellsInWindow[id][trader] = 1;
            } else {
                sellsInWindow[id][trader]++;
            }
        }
        return (this.afterSwap.selector, 0);
    }
}
