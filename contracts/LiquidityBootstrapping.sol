// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Rewrite of kadenzipfel uni-lbp (AGPL). Linear-decay sale via beforeSwapReturnDelta.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";

/// @title LiquidityBootstrapping
/// @notice Sale phase: ETH buys token1 at linearly decaying price; no v4 LP during sale.
contract LiquidityBootstrapping is BaseHook {
    using PoolIdLibrary for PoolKey;
    using SafeCast for uint256;

    error NotInSale();
    error SaleEnded();
    error WrongDirection();

    struct Sale {
        uint256 start;
        uint256 end;
        uint256 startPrice;
        uint256 endPrice;
        uint256 sold;
    }

    mapping(PoolId => Sale) public sales;

    constructor(IPoolManager poolManager) BaseHook(poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function configureSale(
        PoolKey calldata key,
        uint256 start,
        uint256 end,
        uint256 startPrice,
        uint256 endPrice
    ) external {
        sales[key.toId()] = Sale({start: start, end: end, startPrice: startPrice, endPrice: endPrice, sold: 0});
    }

    function currentPrice(PoolId id) public view returns (uint256) {
        Sale memory s = sales[id];
        if (block.timestamp <= s.start) return s.startPrice;
        if (block.timestamp >= s.end) return s.endPrice;
        uint256 elapsed = block.timestamp - s.start;
        uint256 duration = s.end - s.start;
        if (s.startPrice <= s.endPrice) {
            return s.startPrice + (s.endPrice - s.startPrice) * elapsed / duration;
        }
        return s.startPrice - (s.startPrice - s.endPrice) * elapsed / duration;
    }

    function _beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        revert("No v4 liquidity during LBP");
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (!params.zeroForOne) revert WrongDirection();
        PoolId id = key.toId();
        Sale storage s = sales[id];
        if (s.end == 0) revert NotInSale();
        if (block.timestamp >= s.end) revert SaleEnded();

        if (params.amountSpecified >= 0) revert("exact output sale NYI");

        uint256 ethIn = uint256(-params.amountSpecified);
        uint256 price = currentPrice(id);
        uint256 tokensOut = ethIn * 1e18 / price;
        s.sold += tokensOut;

        poolManager.mint(address(this), key.currency0.toId(), ethIn);
        poolManager.burn(address(this), key.currency1.toId(), tokensOut);

        int128 inAmt = ethIn.toInt128();
        int128 outAmt = tokensOut.toInt128();
        return (this.beforeSwap.selector, toBeforeSwapDelta(inAmt, -outAmt), 0);
    }
}
