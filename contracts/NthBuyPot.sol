// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Spark Nth-buy Pot (usespark.fun/builder).
// Exact-input buys: potBps to jackpot; counter advances at most once per block; Nth buyer wins.

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
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title NthBuyPot
/// @notice Deterministic Nth-buy jackpot with claim-backed pot (no random draw).
contract NthBuyPot is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;
    using SafeCast for uint256;

    error NotNativePair();
    error NothingToClaim();
    error NotWinner();

    struct PotState {
        uint256 buyCount;
        uint256 lastCountBlock;
        address winner;
        bool claimed;
    }

    mapping(PoolId => PotState) public pots;

    uint256 public immutable nthBuy;
    uint16 public immutable potBps;

    constructor(IPoolManager poolManager, uint256 _nthBuy, uint16 _potBps) BaseHook(poolManager) {
        nthBuy = _nthBuy;
        potBps = _potBps;
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

    function traderOf(address sender, bytes calldata hookData) public pure returns (address) {
        if (hookData.length >= 32) return abi.decode(hookData, (address));
        return sender;
    }

    function potBalance(PoolKey calldata key) public view returns (uint256) {
        return IERC20(Currency.unwrap(key.currency1)).balanceOf(address(this));
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal pure override returns (bytes4) {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        return this.afterInitialize.selector;
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        if (!params.zeroForOne || params.amountSpecified >= 0) return (this.afterSwap.selector, 0);

        int128 tokenOut = delta.amount1();
        if (tokenOut <= 0) return (this.afterSwap.selector, 0);

        PoolId poolId = key.toId();
        PotState storage state = pots[poolId];

        if (block.number != state.lastCountBlock) {
            state.lastCountBlock = block.number;
            state.buyCount++;
            if (state.buyCount == nthBuy) {
                state.winner = traderOf(sender, hookData);
            }
        }

        uint256 contribution = (uint256(int256(tokenOut)) * potBps) / 10_000;
        if (contribution == 0) return (this.afterSwap.selector, 0);

        key.currency1.take(poolManager, address(this), contribution, false);
        return (this.afterSwap.selector, contribution.toInt128());
    }

    function claim(PoolKey calldata key) external {
        PotState storage state = pots[key.toId()];
        if (state.winner == address(0) || state.buyCount < nthBuy) revert NothingToClaim();
        if (msg.sender != state.winner) revert NotWinner();
        if (state.claimed) revert NothingToClaim();

        state.claimed = true;
        uint256 amount = potBalance(key);
        if (amount > 0) {
            IERC20(Currency.unwrap(key.currency1)).transfer(state.winner, amount);
        }
    }
}
