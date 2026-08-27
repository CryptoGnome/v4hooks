// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SniperTax} from "../contracts/SniperTax.sol";

contract SniperTaxTest is Deployers {
    using PoolIdLibrary for PoolKey;

    SniperTax hook;
    uint24 constant START = 990_000;
    uint24 constant BASE = 10_000;
    uint256 constant DURATION = 10;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG));
        deployCodeTo("SniperTax.sol:SniperTax", abi.encode(manager, START, BASE, DURATION), flags);
        hook = SniperTax(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_feeFor_atLaunch() public view {
        assertEq(hook.feeFor(key.toId()), START);
    }

    function test_feeFor_afterDuration() public {
        vm.warp(block.timestamp + DURATION + 1);
        assertEq(hook.feeFor(key.toId()), BASE);
    }

    function test_feeFor_halfway() public {
        vm.warp(block.timestamp + DURATION / 2);
        uint24 fee = hook.feeFor(key.toId());
        assertGt(fee, BASE);
        assertLt(fee, START);
    }
}
