// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {ReferralFee} from "../contracts/ReferralFee.sol";

contract ReferralFeeTest is Test, Deployers {
    ReferralFee hook;
    address ref = address(0xBEEF);

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG));
        deployCodeTo("ReferralFee.sol:ReferralFee", abi.encode(manager, 500), flags);
        hook = ReferralFee(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_referrerGetsPaid() public {
        uint256 before = MockERC20(Currency.unwrap(key.currency1)).balanceOf(ref);
        swap(key, true, -1e18, abi.encode(ref));
        assertGt(MockERC20(Currency.unwrap(key.currency1)).balanceOf(ref), before);
    }

    function test_referrerOf_empty() public view {
        assertEq(hook.referrerOf(""), address(0));
    }
}
