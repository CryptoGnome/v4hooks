// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MedianOracle} from "../contracts/MedianOracle.sol";

contract MedianOracleTest is Deployers {
    using PoolIdLibrary for PoolKey;

    MedianOracle hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_SWAP_FLAG));
        deployCodeTo("MedianOracle.sol:MedianOracle", abi.encode(manager), flags);
        hook = MedianOracle(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_medianTick_afterSwaps() public {
        PoolId id = key.toId();
        swap(key, true, -1e17, ZERO_BYTES);
        swap(key, false, -1e17, ZERO_BYTES);
        assertGt(hook.medianTick(id), type(int24).min);
    }
}
