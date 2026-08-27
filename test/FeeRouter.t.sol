// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {FeeRouter} from "../contracts/FeeRouter.sol";

contract FeeRouterTest is Deployers {
    FeeRouter hook;
    address treasury = address(0x2001);

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG));
        deployCodeTo("FeeRouter.sol:FeeRouter", abi.encode(manager, treasury, 500), flags);
        hook = FeeRouter(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_treasuryReceivesSkim() public {
        uint256 before = MockERC20(Currency.unwrap(key.currency1)).balanceOf(treasury);
        swap(key, true, -1e18, ZERO_BYTES);
        assertGt(MockERC20(Currency.unwrap(key.currency1)).balanceOf(treasury), before);
    }
}
