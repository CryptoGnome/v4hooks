// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Spark launchpad Anti-Snipe (usespark.fun/builder).
// Not Spark source. Experimental — not an audit.

import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";

interface IERC20Supply {
    function totalSupply() external view returns (uint256);
}

/// @title AntiSnipe
/// @notice Launch guard: max buy (% supply), snipe tax on exact-input buys for N blocks after init.
contract AntiSnipe is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using SafeCast for uint256;

    error NotNativePair();
    error NotDynamicFee();

    /// @dev PoolId → block.number at graduation (afterInitialize).
    mapping(PoolId => uint256) public graduationBlock;

    uint256 public immutable guardBlocks;
    uint16 public immutable maxBuyBps;
    uint24 public immutable baseLpFee;
    uint24 public immutable snipeTax;

    constructor(IPoolManager poolManager, uint256 _guardBlocks, uint16 _maxBuyBps, uint24 _baseLpFee, uint24 _snipeTax)
        BaseHook(poolManager)
    {
        guardBlocks = _guardBlocks;
        maxBuyBps = _maxBuyBps;
        baseLpFee = _baseLpFee;
        snipeTax = _snipeTax;
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
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function inGuardWindow(PoolId poolId) public view returns (bool) {
        uint256 start = graduationBlock[poolId];
        return start != 0 && block.number < start + guardBlocks;
    }

    function maxBuyAmount(PoolKey calldata key) public view returns (uint256) {
        return FullMath.mulDiv(IERC20Supply(Currency.unwrap(key.currency1)).totalSupply(), maxBuyBps, 10_000);
    }

    function feeFor(PoolId poolId, bool isExactInputBuy) public view returns (uint24) {
        if (inGuardWindow(poolId) && isExactInputBuy) return snipeTax;
        return baseLpFee;
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal override returns (bytes4) {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        graduationBlock[key.toId()] = block.number;
        return this.afterInitialize.selector;
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        bool isExactInputBuy = params.zeroForOne && params.amountSpecified < 0;
        uint24 fee = feeFor(key.toId(), isExactInputBuy);
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        if (!inGuardWindow(key.toId())) return (this.afterSwap.selector, 0);
        if (!params.zeroForOne || params.amountSpecified >= 0) return (this.afterSwap.selector, 0);
        int128 tokenOut = delta.amount1();
        if (tokenOut <= 0) return (this.afterSwap.selector, 0);
        uint256 excess = _excessOverCap(key, uint256(int256(tokenOut)));
        if (excess == 0) return (this.afterSwap.selector, 0);
        key.currency1.take(poolManager, address(this), excess, false);
        return (this.afterSwap.selector, excess.toInt128());
    }

    function excessOverCap(PoolKey calldata key, uint256 tokenOut) external view returns (uint256) {
        return _excessOverCap(key, tokenOut);
    }

    function _excessOverCap(PoolKey calldata key, uint256 out) private view returns (uint256) {
        uint256 cap = maxBuyAmount(key);
        return out <= cap ? 0 : out - cap;
    }
}
