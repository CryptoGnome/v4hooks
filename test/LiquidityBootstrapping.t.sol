// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LiquidityBootstrapping} from "../contracts/LiquidityBootstrapping.sol";

contract LiquidityBootstrappingTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    LiquidityBootstrapping hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags =
            address(uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG));
        deployCodeTo("LiquidityBootstrapping.sol:LiquidityBootstrapping", abi.encode(manager), flags);
        hook = LiquidityBootstrapping(flags);
        deployMintAndApprove2Currencies();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
    }

    function test_currentPrice_decays() public {
        uint256 start = block.timestamp;
        hook.configureSale(key, start, start + 1000, 2e18, 1e18);
        PoolId id = key.toId();
        assertEq(hook.currentPrice(id), 2e18);
        vm.warp(start + 500);
        assertEq(hook.currentPrice(id), 15e17);
        vm.warp(start + 1000);
        assertEq(hook.currentPrice(id), 1e18);
    }
}
