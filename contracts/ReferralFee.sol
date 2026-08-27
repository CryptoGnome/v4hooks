// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Inspired by mergd/ref-fee-hook (MIT). hookData referrer receives refBps of swap output.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ReferralFee
/// @notice abi.encode(referrer) in hookData: refBps of output token sent to referrer after swap.
contract ReferralFee is BaseHook {
    using CurrencySettler for Currency;
    using SafeCast for uint256;

    uint16 public immutable refBps;

    constructor(IPoolManager poolManager, uint16 _refBps) BaseHook(poolManager) {
        refBps = _refBps;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
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

    function referrerOf(bytes calldata hookData) public pure returns (address ref) {
        if (hookData.length < 32) return address(0);
        ref = abi.decode(hookData, (address));
    }

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata hookData)
        internal
        override
        returns (bytes4, int128)
    {
        address ref = referrerOf(hookData);
        if (ref == address(0)) return (this.afterSwap.selector, 0);

        Currency outCur = params.zeroForOne ? key.currency1 : key.currency0;
        int128 out = params.zeroForOne ? delta.amount1() : delta.amount0();
        if (out <= 0) return (this.afterSwap.selector, 0);

        uint256 pay = (uint256(int256(out)) * refBps) / 10_000;
        if (pay == 0) return (this.afterSwap.selector, 0);

        outCur.take(poolManager, address(this), pay, false);
        IERC20(Currency.unwrap(outCur)).transfer(ref, pay);
        return (this.afterSwap.selector, pay.toInt128());
    }
}
