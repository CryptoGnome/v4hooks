// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MevWindow} from "../contracts/MevWindow.sol";

contract MevWindowTest is Deployers {
    using PoolIdLibrary for PoolKey;

    MevWindow hook;
    uint256 constant MEV_BLOCKS = 5;
    uint24 constant BASE = 3000;
    uint24 constant MEV = 100_000;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(
            uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG)
        );
        deployCodeTo("MevWindow.sol:MevWindow", abi.encode(manager, MEV_BLOCKS, BASE, MEV), flags);
        hook = MevWindow(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
    }

    function test_inMevWindow_trueThenExpires() public view {
        PoolId id = key.toId();
        assertTrue(hook.inMevWindow(id));
        assertEq(hook.feeFor(id), MEV);
    }

    function test_inMevWindow_expiresAfterRoll() public {
        PoolId id = key.toId();
        vm.roll(block.number + MEV_BLOCKS);
        assertFalse(hook.inMevWindow(id));
        assertEq(hook.feeFor(id), BASE);
    }

    function test_addLiquidityBlockedDuringWindow() public {
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_addLiquidityAfterWindow() public {
        vm.roll(block.number + MEV_BLOCKS + 1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }
}
