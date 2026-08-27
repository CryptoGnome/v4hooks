// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Buyback} from "../contracts/Buyback.sol";

contract BuybackTest is Deployers {
    Buyback hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG));
        deployCodeTo("Buyback.sol:Buyback", abi.encode(manager), flags);
        hook = Buyback(payable(flags));
        deployMintAndApprove2Currencies();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 100 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 10 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        hook.setThreshold(key, -1000);
    }

    function test_buyback_revertsAboveThreshold() public {
        vm.deal(address(hook), 1 ether);
        vm.expectRevert(Buyback.PriceAboveThreshold.selector);
        hook.buyback(key, 0.1 ether);
    }
}
