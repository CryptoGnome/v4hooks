// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SuckerPunch} from "../contracts/SuckerPunch.sol";

contract SuckerPunchTest is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    SuckerPunch hook;

    function setUp() public {
        deployFreshManagerAndRouters();

        address flags =
            address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));
        deployCodeTo("contracts/SuckerPunch.sol:SuckerPunch", abi.encode(manager), flags);
        hook = SuckerPunch(flags);

        deployMintAndApprove2Currencies();
    }

    function test_permissions_matchFlags() public view {
        Hooks.Permissions memory p = hook.getHookPermissions();
        assertTrue(p.afterInitialize);
        assertTrue(p.beforeSwap);
        assertTrue(p.afterSwap);
        assertFalse(p.beforeSwapReturnDelta);
        assertFalse(p.afterSwapReturnDelta);
    }

    function test_feeFor_buyIsZero() public {
        PoolId id = PoolId.wrap(bytes32(uint256(1)));
        assertEq(hook.feeFor(id, address(this), true), 0);
    }

    function test_feeFor_neverBoughtPaysBase() public {
        PoolId id = PoolId.wrap(bytes32(uint256(1)));
        assertEq(hook.feeFor(id, address(0xBEEF), false), hook.BASE_FEE());
    }

    function test_feeFor_decaysOverHoldPeriod() public {
        // Drive state via afterSwap path: initialize a native pair pool and buy.
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        // Seed liquidity with ETH value
        vm.deal(address(this), 100 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 10 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        address trader = address(0xA11CE);
        bytes memory data = abi.encode(trader);

        // Buy token with ETH (zeroForOne)
        swap(key, true, -1 ether, data);

        PoolId id = key.toId();
        // Leave the buy block so the sell fee is hold-time, not same-block MEV tax.
        vm.warp(block.timestamp + 1);
        assertEq(hook.feeFor(id, trader, false), hook.BASE_FEE());

        vm.warp(block.timestamp + hook.HOLD_PERIOD() / 2);
        uint24 mid = hook.feeFor(id, trader, false);
        assertLt(mid, hook.BASE_FEE());
        assertGt(mid, hook.MIN_FEE());

        vm.warp(block.timestamp + hook.HOLD_PERIOD());
        assertEq(hook.feeFor(id, trader, false), hook.MIN_FEE());
    }

    function test_feeFor_sameBlockSellIsMevTax() public {
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 100 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 10 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);

        address trader = address(0xB0B);
        bytes memory data = abi.encode(trader);
        swap(key, true, -1 ether, data);

        assertEq(hook.feeFor(key.toId(), trader, false), hook.MEV_FEE());
    }

    function test_traderOf_prefersHookData() public view {
        address sender = address(0x1);
        address trader = address(0x2);
        assertEq(hook.traderOf(sender, abi.encode(trader)), trader);
        assertEq(hook.traderOf(sender, ""), sender);
    }

    function test_afterInitialize_rejectsNonNative() public {
        // PoolManager wraps hook reverts; NotNativePair is in the bubble.
        vm.expectRevert();
        initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
    }
}
