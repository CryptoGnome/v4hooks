// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {NthBuyPot} from "../contracts/NthBuyPot.sol";

contract NthBuyPotTest is Deployers {
    NthBuyPot hook;
    uint256 constant NTH = 3;
    uint16 constant POT_BPS = 50;

    function setUp() public {
        deployFreshManagerAndRouters();
        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG));
        deployCodeTo("NthBuyPot.sol:NthBuyPot", abi.encode(manager, NTH, POT_BPS), flags);
        hook = NthBuyPot(flags);
        deployMintAndApprove2Currencies();
        currency0 = CurrencyLibrary.ADDRESS_ZERO;
        (key,) = initPool(currency0, currency1, IHooks(address(hook)), LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
        vm.deal(address(this), 200 ether);
        modifyLiquidityRouter.modifyLiquidity{value: 50 ether}(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function _buy(bytes memory hookData) internal {
        swap(key, true, -0.01 ether, hookData);
        swap(key, false, -1e15, ZERO_BYTES);
    }

    function test_buySwapWorks() public {
        swap(key, true, -1 ether, ZERO_BYTES);
    }

    function test_counterAdvancesOncePerBlock() public {
        _buy(ZERO_BYTES);
        (uint256 count,,,) = _pot();
        assertEq(count, 1);
        vm.roll(block.number + 1);
        _buy(ZERO_BYTES);
        (count,,,) = _pot();
        assertEq(count, 2);
    }

    function test_nthBuyerWinsAndClaims() public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);

        _buy(abi.encode(alice));
        vm.roll(block.number + 1);
        _buy(abi.encode(bob));
        vm.roll(block.number + 1);
        _buy(abi.encode(alice));

        (,, address winner,) = _pot();
        assertEq(winner, alice);
        assertGt(hook.potBalance(key), 0);

        uint256 before = currency1.balanceOf(alice);
        vm.prank(alice);
        hook.claim(key);
        assertGt(currency1.balanceOf(alice), before);
    }

    function test_nonWinnerCannotClaim() public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);

        for (uint256 i; i < NTH; i++) {
            vm.roll(block.number + 1);
            _buy(abi.encode(i == NTH - 1 ? alice : bob));
        }

        vm.prank(bob);
        vm.expectRevert(NthBuyPot.NotWinner.selector);
        hook.claim(key);
    }

    function _pot() internal view returns (uint256, uint256, address, bool) {
        (uint256 buyCount, uint256 lastBlock, address winner, bool claimed) = hook.pots(key.toId());
        return (buyCount, lastBlock, winner, claimed);
    }
}
