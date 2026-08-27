// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {LpRewards} from "../contracts/LpRewards.sol";

contract LpRewardsTest is Deployers {
    using StateLibrary for IPoolManager;

    LpRewards hook;
    uint16 constant REWARD_BPS = 500;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG));
        deployCodeTo("LpRewards.sol:LpRewards", abi.encode(manager, REWARD_BPS), flags);
        hook = LpRewards(flags);
        deployMintAndApprove2Currencies();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 200 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 50 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_donateIncreasesFeeGrowth() public {
        (uint256 fg0Before, uint256 fg1Before) = manager.getFeeGrowthGlobals(key.toId());
        swap(key, true, -0.001 ether, ZERO_BYTES);
        swap(key, false, -1e15, ZERO_BYTES);
        hook.flush(key);
        (uint256 fg0After, uint256 fg1After) = manager.getFeeGrowthGlobals(key.toId());
        assertEq(fg0After, fg0Before);
        assertGt(fg1After, fg1Before);
        assertEq(hook.pending(key.toId()), 0);
    }

    function test_pendingAccumulatesBeforeFlush() public {
        swap(key, true, -0.01 ether, ZERO_BYTES);
        assertGt(hook.pending(key.toId()), 0);
    }

    function test_sellSkipsDonate() public {
        (, uint256 fg1Before) = manager.getFeeGrowthGlobals(key.toId());
        swap(key, false, -1e18, ZERO_BYTES);
        (, uint256 fg1After) = manager.getFeeGrowthGlobals(key.toId());
        assertEq(fg1After, fg1Before);
        assertEq(hook.pending(key.toId()), 0);
    }
}
