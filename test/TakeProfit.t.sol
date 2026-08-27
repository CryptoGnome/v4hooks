// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {TakeProfit} from "../contracts/TakeProfit.sol";

contract TakeProfitTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    TakeProfit hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG));
        deployCodeTo("TakeProfit.sol:TakeProfit", abi.encode(manager), flags);
        hook = TakeProfit(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_registerProfit() public {
        hook.registerProfit(key, key.tickSpacing, 2e18);
        assertEq(hook.profitAtTick(key.toId(), key.tickSpacing), 2e18);
    }
}
