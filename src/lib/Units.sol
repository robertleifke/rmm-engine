// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ABDKMath64x64.sol";

error Min();

function abs(int256 input) pure returns (uint256 output) {
    if (input == type(int256).min) revert Min();
    if (input < 0) {
        assembly {
            output := add(not(input), 1)
        }
    } else {
        assembly {
            output := input
        }
    }
}

/// @dev From solmate@v7, changes last `div` to `sdiv`.
function muli(int256 x, int256 y, int256 denominator) pure returns (int256 z) {
    assembly {
        // Store x * y in z for now.
        z := mul(x, y)

        // Equivalent to require(denominator != 0 && (x == 0 || (x * y) / x == y))
        if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(sdiv(z, x), y)))) { revert(0, 0) }

        // Divide z by the denominator.
        z := sdiv(z, denominator)
    }
}

function muliWad(int256 x, int256 y) pure returns (int256 z) {
    z = muli(x, y, 1 ether);
}

function diviWad(int256 x, int256 y) pure returns (int256 z) {
    z = muli(x, 1 ether, y);
}

// Extension functions for int128
library Units {
    using Units for int128;
    using Units for uint256;

    int128 internal constant ONE_INT = 0x10000000000000000;

    /// @notice Convert years to fixed point 64.64 format
    function toYears(uint256 tau) internal pure returns (int128) {
        return int128(int256(tau * uint256(1e18) / 31556952)); // Convert seconds to years
    }

    /// @notice Convert percentage to fixed point 64.64 format
    function percentageToX64(uint256 percentage) internal pure returns (int128) {
        return int128(int256(percentage * uint256(1e18) / 10000)); // Convert basis points to fixed point
    }

    /// @notice Scale value to fixed point 64.64 format
    function scaleToX64(uint256 value, uint256 scaleFactor) internal pure returns (int128) {
        return int128(int256(value * uint256(1e18) / scaleFactor));
    }

    /// @notice Scale value from fixed point 64.64 format
    function scaleFromX64(int128 value, uint256 scaleFactor) internal pure returns (uint256) {
        return uint256(int256(value) * int256(scaleFactor) / int256(1e18));
    }

    /// @notice Get square root of fixed point 64.64 number
    function sqrt(int128 x) internal pure returns (int128) {
        if (x < 0) revert();
        if (x == 0) return 0;

        int128 z = (x + 1) / 2;
        int128 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}

// Extension functions for int256 to support wad math operations
library WadMath {
    using WadMath for int256;

    /// @notice Exponential function for wad math
    function wadExp(int256 x) internal pure returns (int256) {
        if (x >= 0) {
            return int256(ABDKMath64x64.exp(int128(x)));
        } else {
            return int256(1e18) / int256(ABDKMath64x64.exp(int128(-x)));
        }
    }

    /// @notice Natural logarithm for wad math
    function lnWad(int256 x) internal pure returns (int256) {
        require(x > 0, "UNDEFINED");
        return int256(ABDKMath64x64.ln(int128(x)));
    }

    /// @notice Exponential function for wad math (alternative name)
    function expWad(int256 x) internal pure returns (int256) {
        return wadExp(x);
    }
}
