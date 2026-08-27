// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {AutoBurn} from "../contracts/AutoBurn.sol";

contract AutoBurnTest is Test, Deployers {
    AutoBurn hook;
    uint16 constant BURN_BPS = 500; // 5%

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG));
        deployCodeTo("AutoBurn.sol:AutoBurn", abi.encode(manager, BURN_BPS), flags);
        hook = AutoBurn(flags);
        deployMintAndApprove2Currencies();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 100 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 10 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_burnsBuyOutput() public {
        uint256 deadBefore = currency1.balanceOf(hook.DEAD());
        uint256 balBefore = currency1.balanceOf(address(this));

        swap(key, true, -1 ether, ZERO_BYTES);

        uint256 received = currency1.balanceOf(address(this)) - balBefore;
        uint256 burned = currency1.balanceOf(hook.DEAD()) - deadBefore;
        assertGt(burned, 0);
        assertApproxEqRel(burned, (received + burned) * BURN_BPS / 10_000, 0.01e18);
    }

    function test_sellNotBurned() public {
        swap(key, true, -1 ether, ZERO_BYTES);
        uint256 deadBefore = currency1.balanceOf(hook.DEAD());
        swap(key, false, -1e18, ZERO_BYTES);
        assertEq(currency1.balanceOf(hook.DEAD()), deadBefore);
    }
}
