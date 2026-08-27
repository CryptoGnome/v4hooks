// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {TrailingStop} from "../contracts/TrailingStop.sol";

contract TrailingStopTest is Deployers {
    TrailingStop hook;
    int24 constant TRAIL = 60;
    uint24 constant TRAIL_FEE = 100_000;
    uint24 constant BASE = 3000;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(
            uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG)
        );
        deployCodeTo("TrailingStop.sol:TrailingStop", abi.encode(manager, TRAIL, TRAIL_FEE, BASE), flags);
        hook = TrailingStop(flags);
        deployMintAndApprove2Currencies();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 100 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 10 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_armTrail_setsActive() public {
        address t = address(0xA11CE);
        hook.armTrail(key, t);
        (int24 peak, bool active) = _trail(t);
        assertTrue(active);
        assertEq(peak, 0);
    }

    function test_traderOf_hookData() public view {
        assertEq(hook.traderOf(address(1), abi.encode(address(2))), address(2));
    }

    function _trail(address t) internal view returns (int24 peak, bool active) {
        (peak, active) = hook.trails(key.toId(), t);
    }
}
