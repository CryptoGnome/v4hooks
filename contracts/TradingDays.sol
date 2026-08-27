// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Rewrite of horsefacts trading-days (MIT). Simplified NY cash-market hours gate.
import {BaseHook} from "@openzeppelin/uniswap-hooks/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

/// @title TradingDays
/// @notice beforeSwap reverts outside NY weekday cash session (9:30–16:00 ET, fixed UTC-5).
contract TradingDays is BaseHook {
    error ClosedForWeekend();
    error AfterHours();

    event DingDingDing(address indexed ringer);

    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) public marketOpened;

    constructor(IPoolManager poolManager) BaseHook(poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function nyHour(uint256 ts) public pure returns (uint256 hour, uint256 minute, uint256 wday) {
        uint256 ny = ts - 5 hours;
        wday = (ny / 1 days + 4) % 7;
        uint256 sod = ny % 1 days;
        hour = sod / 1 hours;
        minute = (sod % 1 hours) / 1 minutes;
    }

    function isOpen(uint256 ts) public pure returns (bool) {
        (uint256 h, uint256 m, uint256 d) = nyHour(ts);
        if (d == 0 || d == 6) return false;
        uint256 mins = h * 60 + m;
        return mins >= 570 && mins < 960;
    }

    function _beforeSwap(address sender, PoolKey calldata, SwapParams calldata, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (, , uint256 d) = nyHour(block.timestamp);
        if (d == 0 || d == 6) revert ClosedForWeekend();
        if (!isOpen(block.timestamp)) revert AfterHours();

        (uint256 y, uint256 mo, uint256 day) = _ymd(block.timestamp);
        if (!marketOpened[y][mo][day]) {
            marketOpened[y][mo][day] = true;
            emit DingDingDing(sender);
        }

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _ymd(uint256 ts) internal pure returns (uint256 y, uint256 m, uint256 d) {
        uint256 z = ts / 1 days + 719468;
        uint256 era = z / 146097;
        uint256 doe = z - era * 146097;
        uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        y = yoe + era * 400;
        uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        uint256 mp = (5 * doy + 2) / 153;
        m = mp < 10 ? mp + 3 : mp - 9;
        y += mp < 10 ? 0 : 1;
        d = doy - (153 * mp + 2) / 5 + 1;
    }
}
