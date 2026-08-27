// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {JitVault} from "../contracts/JitVault.sol";

contract JitVaultTest is Deployers {
    using PoolIdLibrary for PoolKey;

    JitVault hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(
            uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
                    | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
            )
        );
        deployCodeTo("JitVault.sol:JitVault", abi.encode(manager, 100), flags);
        hook = JitVault(flags);
        deployMintAndApprove2Currencies();
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), 3000, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_jitActive_setDuringSwap() public {
        PoolId id = key.toId();
        assertFalse(hook.jitActive(id));
        swap(key, true, -1e15, ZERO_BYTES);
        assertFalse(hook.jitActive(id));
    }

    function test_vaultAccruesOnSwap() public {
        PoolId id = key.toId();
        swap(key, true, -1e18, ZERO_BYTES);
        assertGt(hook.vault1(id), 0);
    }
}
