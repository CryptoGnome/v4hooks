// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LiquidityLock} from "../contracts/LiquidityLock.sol";

contract LiquidityLockTest is Deployers {
    LiquidityLock hook;
    uint256 constant LOCK = 1 days;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG));
        deployCodeTo("LiquidityLock.sol:LiquidityLock", abi.encode(manager, LOCK), flags);
        hook = LiquidityLock(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
    }

    function test_unlockTime_setOnAdd() public {
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        assertEq(hook.unlockTime(key.toId(), address(modifyLiquidityRouter)), block.timestamp + LOCK);
    }
}
