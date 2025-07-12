// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ABDKMath64x64} from "./ABDKMath64x64.sol";

/// @title Cumulative Normal Distribution
/// @notice Provides CDF and inverse CDF functions for normal distribution
/// @author @robertleifke
library CumulativeNormalDistribution {
    using ABDKMath64x64 for int128;

    int128 internal constant ONE = 0x10000000000000000;
    int128 internal constant HALF = 0x8000000000000000;
    int128 internal constant TWO = 0x20000000000000000;
    int128 internal constant SQRT2 = 0x16A09E667F3BCC90;

    /// @notice Calculate the cumulative distribution function (CDF) of a standard normal distribution
    /// @param x The input value
    /// @return The CDF value
    function getCdf(int128 x) internal pure returns (int128) {
        if (x >= 0) {
            return HALF.add(erf(x.div(SQRT2)).mul(HALF));
        } else {
            return HALF.sub(erf(x.div(SQRT2)).mul(HALF));
        }
    }

    /// @notice Calculate the inverse cumulative distribution function (inverse CDF) of a standard normal distribution
    /// @param p The probability value (0 < p < 1)
    /// @return The inverse CDF value
    function getInverseCdf(int128 p) internal pure returns (int128) {
        require(p > 0 && p < ONE, "Invalid probability");

        // For p = 0.5, return 0
        if (p == HALF) return 0;

        // For p < 0.5, use negative of inverse CDF of 1-p
        if (p < HALF) {
            return -getInverseCdf(ONE.sub(p));
        }

        // Simple approximation for inverse CDF
        return simpleInverseCdf(p);
    }

    /// @notice Error function approximation using simple series
    /// @param x Input value
    /// @return Error function value
    function erf(int128 x) internal pure returns (int128) {
        if (x >= 0) {
            return ONE.sub(erfc(x));
        } else {
            return erfc(x).sub(ONE);
        }
    }

    /// @notice Complementary error function using simple approximation
    /// @param x Input value
    /// @return Complementary error function value
    function erfc(int128 x) internal pure returns (int128) {
        if (x < 0) {
            return TWO.sub(erfc(-x));
        }

        if (x >= 6) return 0;

        // Very simple approximation to avoid overflow
        if (x >= 2) {
            return exp(-x.mul(x)).div(x.mul(2));
        }

        // For small x, use simple approximation
        return ONE.sub(x.mul(x).div(2));
    }

    /// @notice Exponential function approximation
    /// @param x Input value
    /// @return Exponential value
    function exp(int128 x) internal pure returns (int128) {
        if (x >= 0) {
            return ABDKMath64x64.exp(x);
        } else {
            return ONE.div(ABDKMath64x64.exp(-x));
        }
    }

    /// @notice Simple inverse CDF approximation
    /// @param p Probability value
    /// @return Inverse CDF value
    function simpleInverseCdf(int128 p) internal pure returns (int128) {
        // Simple approximation for p > 0.5
        int128 q = p.sub(HALF);
        int128 sign = q >= 0 ? ONE : -ONE;
        q = q >= 0 ? q : -q;

        // Simple linear approximation
        return sign.mul(q.mul(2));
    }

    /// @notice Addition function
    /// @param x First value
    /// @param y Second value
    /// @return Sum
    function add(int128 x, int128 y) internal pure returns (int128) {
        return x + y;
    }

    /// @notice Subtraction function
    /// @param x First value
    /// @param y Second value
    /// @return Difference
    function sub(int128 x, int128 y) internal pure returns (int128) {
        return x - y;
    }

    /// @notice Multiplication function
    /// @param x First value
    /// @param y Second value
    /// @return Product
    function mul(int128 x, int128 y) internal pure returns (int128) {
        return ABDKMath64x64.mul(x, y);
    }

    /// @notice Division function
    /// @param x First value
    /// @param y Second value
    /// @return Quotient
    function div(int128 x, int128 y) internal pure returns (int128) {
        return ABDKMath64x64.div(x, y);
    }
}
