// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Teaching hook inspired by Spark Surge Fees (usespark.fun/builder).
// Contrast: slippage-fee.yml simulates tick move; this scales fee with size vs pool liquidity.

import {BaseOverrideFee} from "@openzeppelin/uniswap-hooks/fee/BaseOverrideFee.sol";
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

/// @title SurgeFee
/// @notice LP fee rises with swap size relative to pool liquidity (no simulate-and-revert).
contract SurgeFee is BaseOverrideFee {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using LPFeeLibrary for uint24;

    uint24 public immutable baseFee;
    uint24 public immutable maxFee;
    /// @dev Added fee in hundredths of bip per 1e18 of (tradeSize / liquidity).
    uint24 public immutable surgeFactor;

    constructor(IPoolManager poolManager, uint24 _baseFee, uint24 _maxFee, uint24 _surgeFactor) BaseHook(poolManager) {
        baseFee = _baseFee;
        maxFee = _maxFee;
        surgeFactor = _surgeFactor;
    }

    function feeFor(PoolKey calldata key, SwapParams calldata params) public view returns (uint24) {
        uint128 liquidity = poolManager.getLiquidity(key.toId());
        if (liquidity == 0) return baseFee;

        uint256 tradeSize = params.amountSpecified < 0
            ? uint256(-params.amountSpecified)
            : uint256(params.amountSpecified);
        uint256 surge = (tradeSize * uint256(surgeFactor)) / uint256(liquidity);
        uint256 total = uint256(baseFee) + surge;
        if (total > maxFee) return maxFee;
        return uint24(total);
    }

    function _getFee(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        view
        override
        returns (uint24)
    {
        return feeFor(key, params);
    }
}
