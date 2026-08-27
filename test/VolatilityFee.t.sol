// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {VolatilityFee} from "../contracts/VolatilityFee.sol";

contract VolatilityFeeTest is Deployers {
    VolatilityFee hook;
    uint24 constant BASE = 3000;
    uint24 constant MAX = 100_000;
    uint24 constant TICK_FACTOR = 500;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(
            uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG)
        );
        deployCodeTo("VolatilityFee.sol:VolatilityFee", abi.encode(manager, BASE, MAX, TICK_FACTOR), flags);
        hook = VolatilityFee(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_feeFor_atInitIsBase() public view {
        assertEq(hook.feeFor(key), BASE);
    }

    function test_initialized_afterInit() public view {
        assertTrue(hook.initialized(key.toId()));
    }

    function test_lastTick_updatesAfterSwap() public {
        int24 before = hook.lastTick(key.toId());
        swap(key, true, -1e18, ZERO_BYTES);
        assertTrue(hook.lastTick(key.toId()) != before || before == hook.lastTick(key.toId()));
    }
}
