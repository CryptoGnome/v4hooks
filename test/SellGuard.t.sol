// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SellGuard} from "../contracts/SellGuard.sol";

contract SellGuardTest is Test, Deployers {
    SellGuard hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));
        deployCodeTo("SellGuard.sol:SellGuard", abi.encode(manager, 2, 100, 3000, 50_000), flags);
        hook = SellGuard(flags);
        deployMintAndApprove2Currencies();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 100 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 10 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_sellCooldown_blocksRapidSell() public {
        address t = address(0xBEEF);
        swap(key, true, -1 ether, abi.encode(t));
        swap(key, false, -1e15, abi.encode(t));
        vm.expectRevert();
        swap(key, false, -1e15, abi.encode(t));
        vm.roll(block.number + 3);
        swap(key, false, -1e15, abi.encode(t));
    }
}
