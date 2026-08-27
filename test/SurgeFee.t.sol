// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SurgeFee} from "../contracts/SurgeFee.sol";

contract SurgeFeeTest is Test, Deployers {
    SurgeFee hook;
    uint24 constant BASE = 3000;
    uint24 constant MAX = 100_000;
    uint24 constant SURGE = 50_000;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG));
        deployCodeTo("SurgeFee.sol:SurgeFee", abi.encode(manager, BASE, MAX, SURGE), flags);
        hook = SurgeFee(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_feeFor_smallTradeNearBase() public view {
        SwapParams memory p = SWAP_PARAMS;
        p.amountSpecified = -100;
        assertEq(hook.feeFor(key, p), BASE);
    }

    function test_feeFor_largeTradeExceedsBase() public view {
        SwapParams memory p = SWAP_PARAMS;
        p.amountSpecified = -1e18;
        assertGt(hook.feeFor(key, p), BASE);
    }

    function test_feeFor_cappedAtMax() public view {
        SwapParams memory p = SWAP_PARAMS;
        p.amountSpecified = -type(int128).max;
        assertEq(hook.feeFor(key, p), MAX);
    }

    function test_permissions() public view {
        assertTrue(hook.getHookPermissions().beforeSwap);
        assertTrue(hook.getHookPermissions().afterInitialize);
        assertFalse(hook.getHookPermissions().afterSwapReturnDelta);
    }
}
