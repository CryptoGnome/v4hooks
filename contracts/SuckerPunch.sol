// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Inspired by PopFendi's EthLondon 2024 SuckerPunch (MIT):
// https://github.com/popfendi/suckerpunch/blob/main/src/PopFendisSuckerPunch.sol
// Rewritten for current Uniswap v4: 14 permission fields, OVERRIDE_FEE_FLAG,
// OpenZeppelin BaseHook (onlyPoolManager), no tx.origin, fixed hold-fee math.

import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

/// @title SuckerPunch
/// @notice ETH-pair dynamic fee: free buys, hold-time decay on sells, same-block sell tax.
/// @dev Experimental teaching rewrite. Not an audit. Not safe to deploy with size.
contract SuckerPunch is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    error NotNativePair();
    error NotDynamicFee();

    struct BuyData {
        uint256 timestamp;
        uint128 amount;
    }

    /// @dev PoolId → trader → last buy snapshot.
    mapping(PoolId => mapping(address => BuyData)) public buyData;

    /// @dev 50% in hundredths of a bip (matches the original constant; original comment said 5%).
    uint24 public constant BASE_FEE = 500_000;
    /// @dev 0.05%.
    uint24 public constant MIN_FEE = 500;
    /// @dev ~99.9999% tax on same-block buy→sell.
    uint24 public constant MEV_FEE = 999_999;
    /// @dev 90 days.
    uint256 public constant HOLD_PERIOD = 7_776_000;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24)
        internal
        pure
        override
        returns (bytes4)
    {
        if (!key.currency0.isAddressZero()) revert NotNativePair();
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        return this.afterInitialize.selector;
    }

    /// @dev Prefer `abi.encode(trader)` in hookData; otherwise key by swap `sender` (often a router).
    function traderOf(address sender, bytes calldata hookData) public pure returns (address) {
        if (hookData.length >= 32) {
            return abi.decode(hookData, (address));
        }
        return sender;
    }

    /// @notice Linear hold fee from BASE_FEE → MIN_FEE over HOLD_PERIOD. Same-block sell → MEV_FEE.
    function feeFor(PoolId poolId, address trader, bool isBuy) public view returns (uint24) {
        if (isBuy) return 0;

        BuyData memory data = buyData[poolId][trader];
        if (data.timestamp != 0 && data.timestamp == block.timestamp) return MEV_FEE;
        if (data.timestamp == 0) return BASE_FEE;

        uint256 elapsed = block.timestamp - data.timestamp;
        if (elapsed >= HOLD_PERIOD) return MIN_FEE;

        uint256 reduction = (uint256(BASE_FEE - MIN_FEE) * elapsed) / HOLD_PERIOD;
        return uint24(uint256(BASE_FEE) - reduction);
    }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (!key.currency0.isAddressZero()) revert NotNativePair();

        address trader = traderOf(sender, hookData);
        // Native currency0: zeroForOne buys the paired token with ETH.
        bool isBuy = params.zeroForOne;
        uint24 fee = feeFor(key.toId(), trader, isBuy);
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        address trader = traderOf(sender, hookData);
        PoolId poolId = key.toId();

        if (params.zeroForOne) {
            // Buy: credit token1 received (positive amount1 for the swapper path varies by sign;
            // use absolute magnitude of amount1 as inventory proxy).
            uint128 bought = _abs(delta.amount1());
            BuyData storage data = buyData[poolId][trader];
            if (data.timestamp == 0) {
                data.timestamp = block.timestamp;
                data.amount = bought;
            } else {
                data.amount += bought;
            }
        } else {
            // Sell: if dumping more than half of tracked inventory, reset the hold clock.
            BuyData storage data = buyData[poolId][trader];
            if (data.amount != 0) {
                uint128 sold = _abs(delta.amount1());
                if (sold > data.amount / 2) {
                    uint128 remaining = data.amount > sold ? data.amount - sold : 0;
                    data.timestamp = block.timestamp;
                    data.amount = remaining;
                }
            }
        }

        return (this.afterSwap.selector, 0);
    }

    function _abs(int128 x) private pure returns (uint128) {
        return uint128(uint256(int256(x < 0 ? -x : x)));
    }
}
