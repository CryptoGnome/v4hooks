// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {StopLoss} from "../contracts/StopLoss.sol";
import {TickLower} from "../contracts/lib/TickLower.sol";

contract StopLossTest is Deployers {
    using PoolIdLibrary for PoolKey;

    StopLoss hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG));
        deployCodeTo("StopLoss.sol:StopLoss", abi.encode(manager), flags);
        hook = StopLoss(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_tickLowerLast_setOnInit() public view {
        assertEq(hook.tickLowerLast(key.toId()), TickLower.floor(0, key.tickSpacing));
    }

    function test_registerStop() public {
        hook.registerStop(key, 0, 1e18);
        assertEq(hook.stopAtTick(key.toId(), 0), 1e18);
    }
}
