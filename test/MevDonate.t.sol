// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MevDonate} from "../contracts/MevDonate.sol";

contract MevDonateTest is Deployers {
    MevDonate hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG));
        deployCodeTo("MevDonate.sol:MevDonate", abi.encode(manager, 100), flags);
        hook = MevDonate(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_swap_skimsToPending() public {
        swap(key, true, -1e18, ZERO_BYTES);
        assertGt(hook.pendingToken(key.toId()), 0);
    }
}
