// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {TradingDays} from "../contracts/TradingDays.sol";

contract TradingDaysTest is Test, Deployers {
    TradingDays hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.BEFORE_SWAP_FLAG));
        deployCodeTo("TradingDays.sol:TradingDays", abi.encode(manager), flags);
        hook = TradingDays(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_isOpen_weekdayMidday() public {
        // Thu 2024-01-11 15:00 UTC = 10:00 ET
        assertTrue(hook.isOpen(1_704_984_000));
    }

    function test_isOpen_weekend() public {
        // Sat 2024-01-13 15:00 UTC
        assertFalse(hook.isOpen(1_705_157_600));
    }

    function test_swap_revertsWeekend() public {
        vm.warp(1_705_157_600);
        vm.expectRevert();
        swap(key, true, -1e18, ZERO_BYTES);
    }
}
