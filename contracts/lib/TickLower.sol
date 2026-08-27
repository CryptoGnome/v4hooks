// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library TickLower {
    function floor(int24 tick, int24 spacing) internal pure returns (int24) {
        int24 c = tick / spacing;
        if (tick < 0 && tick % spacing != 0) c--;
        return c * spacing;
    }
}
