// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Inspired by FairArbooors (EthLondon) and Detox. Extra swap skim → donate to LPs.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/utils/CurrencySettler.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

/// @title MevDonate
/// @notice Skims skimBps of swap output to pending; flush() donates to in-range LPs.
contract MevDonate is BaseHook, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using SafeCast for uint256;
    using StateLibrary for IPoolManager;

    error NothingPending();
    error NoLiquidityToReceiveDonation();

    mapping(PoolId => uint256) public pendingEth;
    mapping(PoolId => uint256) public pendingToken;

    uint16 public immutable skimBps;

    constructor(IPoolManager poolManager, uint16 _skimBps) BaseHook(poolManager) {
        skimBps = _skimBps;
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

    function _afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        int128 out = params.zeroForOne ? delta.amount1() : delta.amount0();
        if (out <= 0) return (this.afterSwap.selector, 0);

        uint256 skim = (uint256(int256(out)) * skimBps) / 10_000;
        if (skim == 0) return (this.afterSwap.selector, 0);

        if (params.zeroForOne) {
            key.currency1.take(poolManager, address(this), skim, false);
            pendingToken[key.toId()] += skim;
        } else {
            key.currency0.take(poolManager, address(this), skim, false);
            pendingEth[key.toId()] += skim;
        }
        return (this.afterSwap.selector, skim.toInt128());
    }

    function flush(PoolKey calldata key) external {
        poolManager.unlock(abi.encode(key));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        PoolKey memory key = abi.decode(data, (PoolKey));
        PoolId id = key.toId();
        uint256 ethAmt = pendingEth[id];
        uint256 tokAmt = pendingToken[id];
        if (ethAmt == 0 && tokAmt == 0) revert NothingPending();
        if (poolManager.getLiquidity(id) == 0) revert NoLiquidityToReceiveDonation();

        pendingEth[id] = 0;
        pendingToken[id] = 0;
        poolManager.donate(key, ethAmt, tokAmt, "");
        if (ethAmt > 0) key.currency0.settle(poolManager, address(this), ethAmt, false);
        if (tokAmt > 0) key.currency1.settle(poolManager, address(this), tokAmt, false);
        return "";
    }
}
