// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {VolumeTier} from "../contracts/VolumeTier.sol";

contract VolumeTierTest is Deployers {
    VolumeTier hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));
        deployCodeTo("VolumeTier.sol:VolumeTier", abi.encode(manager, 1 ether, 5 ether, 10_000, 5000, 1000), flags);
        hook = VolumeTier(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_feeFor_tiers() public {
        address t = address(0x1);
        assertEq(hook.feeFor(key.toId(), t), 10_000);
        swap(key, true, -2 ether, abi.encode(t));
        assertEq(hook.feeFor(key.toId(), t), 5000);
    }
}
