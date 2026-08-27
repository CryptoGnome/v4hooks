// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Inspired by EthLondon Royalty Swap (Keinberger/royalty-swap). Volume tiers reduce swap fee.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

/// @title VolumeTier
/// @notice Cumulative swap notional per trader unlocks lower beforeSwap fees.
contract VolumeTier is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    error NotDynamicFee();

    mapping(PoolId => mapping(address => uint256)) public volume;

    uint256 public immutable tier1;
    uint256 public immutable tier2;
    uint24 public immutable fee0;
    uint24 public immutable fee1;
    uint24 public immutable fee2;

    constructor(
        IPoolManager poolManager,
        uint256 _tier1,
        uint256 _tier2,
        uint24 _fee0,
        uint24 _fee1,
        uint24 _fee2
    ) BaseHook(poolManager) {
        tier1 = _tier1;
        tier2 = _tier2;
        fee0 = _fee0;
        fee1 = _fee1;
        fee2 = _fee2;
    }

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

    function traderOf(address sender, bytes calldata hookData) public pure returns (address) {
        if (hookData.length >= 32) return abi.decode(hookData, (address));
        return sender;
    }

    function feeFor(PoolId id, address trader) public view returns (uint24) {
        uint256 v = volume[id][trader];
        if (v >= tier2) return fee2;
        if (v >= tier1) return fee1;
        return fee0;
    }

    function _afterInitialize(address, PoolKey calldata key, uint160, int24) internal pure override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert NotDynamicFee();
        return this.afterInitialize.selector;
    }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata, bytes calldata hookData)
        internal
        view
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address trader = traderOf(sender, hookData);
        uint24 fee = feeFor(key.toId(), trader);
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
        uint256 notional =
            params.amountSpecified < 0 ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
        volume[key.toId()][trader] += notional;
        return (this.afterSwap.selector, 0);
    }
}
