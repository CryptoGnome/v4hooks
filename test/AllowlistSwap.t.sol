// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {AllowlistSwap} from "../contracts/AllowlistSwap.sol";

contract AllowlistSwapTest is Deployers {
    using PoolIdLibrary for PoolKey;

    AllowlistSwap hook;
    address gate = address(0x1001);
    address trader = address(0xCAFE);

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.BEFORE_SWAP_FLAG));
        deployCodeTo("AllowlistSwap.sol:AllowlistSwap", abi.encode(manager, gate), flags);
        hook = AllowlistSwap(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        vm.prank(gate);
        hook.setAllowed(key.toId(), trader, true);
    }

    function test_swapAllowed() public {
        swap(key, true, -1e15, abi.encode(trader));
    }

    function test_swapRevertsWhenNotAllowed() public {
        vm.expectRevert();
        swap(key, true, -1e15, ZERO_BYTES);
    }

    function test_traderOf_hookData() public view {
        assertEq(hook.traderOf(address(this), abi.encode(trader)), trader);
        assertEq(hook.traderOf(address(this), ""), address(this));
    }
}
