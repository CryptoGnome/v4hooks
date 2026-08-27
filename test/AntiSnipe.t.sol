// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {AntiSnipe} from "../contracts/AntiSnipe.sol";

contract AntiSnipeTest is Deployers {
    using PoolIdLibrary for PoolKey;

    AntiSnipe hook;
    uint256 constant GUARD = 5;
    uint16 constant MAX_BUY_BPS = 50; // 0.5%
    uint24 constant BASE_FEE = 3000;
    uint24 constant SNIPE_TAX = 400_000; // 40%

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(
            uint160(
                Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                    | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
            )
        );
        deployCodeTo(
            "AntiSnipe.sol:AntiSnipe",
            abi.encode(manager, GUARD, MAX_BUY_BPS, BASE_FEE, SNIPE_TAX),
            flags
        );
        hook = AntiSnipe(flags);
        deployMintAndApprove2Currencies();
    }

    function _initNativePool() internal returns (PoolId id) {
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 200 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 50 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);
        id = key.toId();
    }

    function test_inGuardWindow_falseBeforeInit() public view {
        assertFalse(hook.inGuardWindow(PoolId.wrap(bytes32(uint256(1)))));
    }

    function test_inGuardWindow_trueThenExpires() public {
        PoolId id = _initNativePool();
        assertTrue(hook.inGuardWindow(id));
        vm.roll(block.number + GUARD);
        assertFalse(hook.inGuardWindow(id));
    }

    function test_feeFor_snipeTaxDuringGuard() public {
        PoolId id = _initNativePool();
        assertEq(hook.feeFor(id, true), SNIPE_TAX);
        assertEq(hook.feeFor(id, false), BASE_FEE);
        vm.roll(block.number + GUARD);
        assertEq(hook.feeFor(id, true), BASE_FEE);
    }

    function test_maxBuyAmount_fromSupply() public {
        _initNativePool();
        uint256 supply = MockERC20(Currency.unwrap(key.currency1)).totalSupply();
        assertEq(hook.maxBuyAmount(key), FullMath.mulDiv(supply, MAX_BUY_BPS, 10_000));
    }

    function test_excessOverCap() public {
        _initNativePool();
        uint256 cap = hook.maxBuyAmount(key);
        assertEq(hook.excessOverCap(key, cap), 0);
        assertEq(hook.excessOverCap(key, cap + 100), 100);
    }

    function test_afterSwap_capsBuyOutputInGuard() public {
        _initNativePool();
        uint256 cap = hook.maxBuyAmount(key);
        uint256 balBefore = currency1.balanceOf(address(this));
        swap(key, true, -1 ether, ZERO_BYTES);
        uint256 received = currency1.balanceOf(address(this)) - balBefore;
        assertLe(received, cap);
    }

    function test_afterSwap_noCapAfterGuard() public {
        _initNativePool();
        vm.roll(block.number + GUARD);
        uint256 balBefore = currency1.balanceOf(address(this));
        swap(key, true, -1 ether, ZERO_BYTES);
        assertGt(currency1.balanceOf(address(this)) - balBefore, 0);
    }
}
