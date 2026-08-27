// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Spark Auto Burn (usespark.fun/builder).
// Exact-input buys only: burns a share of token output via afterSwapReturnDelta.

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
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title AutoBurn
/// @notice Burns burnBps of token output on exact-input buys (native currency0 pairs).
contract AutoBurn is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using SafeCast for uint256;

    error NotNativePair();

    address public constant DEAD = address(0xdead);

    uint16 public immutable burnBps;

    constructor(IPoolManager poolManager, uint16 _burnBps) BaseHook(poolManager) {
        burnBps = _burnBps;
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

        uint256 burnAmount = (uint256(int256(tokenOut)) * burnBps) / 10_000;
        if (burnAmount == 0) return (this.afterSwap.selector, 0);

        key.currency1.take(poolManager, address(this), burnAmount, false);
        IERC20(Currency.unwrap(key.currency1)).transfer(DEAD, burnAmount);

        return (this.afterSwap.selector, burnAmount.toInt128());
    }
}
