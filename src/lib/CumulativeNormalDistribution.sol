// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ABDKMath64x64.sol";

/// @title Cumulative Normal Distribution
/// @notice Provides CDF and inverse CDF functions for normal distribution
/// @author @robertleifke
library CumulativeNormalDistribution {
    using ABDKMath64x64 for int128;

    int128 internal constant ONE = 0x10000000000000000;
    int128 internal constant HALF = 0x8000000000000000;
    int128 internal constant TWO = 0x20000000000000000;
    int128 internal constant SQRT2 = 0x16A09E667F3BCC90;
    int128 internal constant SQRT_2PI = 0x2C5C85FDF473DE6B;

    /// @notice Calculate the cumulative distribution function (CDF) of a standard normal distribution
    /// @param x The input value
    /// @return The CDF value
    function getCDF(int128 x) internal pure returns (int128) {
        if (x >= 0) {
            return HALF.add(erf(x.div(SQRT2)).mul(HALF));
        } else {
            return HALF.sub(erf(x.div(SQRT2)).mul(HALF));
        }
    }

    /// @notice Calculate the inverse cumulative distribution function (inverse CDF) of a standard normal distribution
    /// @param p The probability value (0 < p < 1)
    /// @return The inverse CDF value
    function getInverseCDF(int128 p) internal pure returns (int128) {
        require(p > 0 && p < ONE, "Invalid probability");
        
        // For p = 0.5, return 0
        if (p == HALF) return 0;
        
        // For p < 0.5, use negative of inverse CDF of 1-p
        if (p < HALF) {
            return -getInverseCDF(ONE.sub(p));
        }
        
        // Use approximation for inverse CDF
        return inverseCDFApproximation(p);
    }

    /// @notice Error function approximation
    /// @param x Input value
    /// @return Error function value
    function erf(int128 x) internal pure returns (int128) {
        if (x >= 0) {
            return ONE.sub(erfc(x));
        } else {
            return erfc(x).sub(ONE);
        }
    }

    /// @notice Complementary error function approximation
    /// @param x Input value
    /// @return Complementary error function value
    function erfc(int128 x) internal pure returns (int128) {
        if (x < 0) {
            return TWO.sub(erfc(-x));
        }
        
        if (x >= 6) return 0;
        
        int128 t = ONE.div(ONE.add(x.div(2)));
        int128 u = t.mul(t);
        
        int128 result = t.mul(
            -1265512230000000000 + 1000023680000000000 * u + 374091960000000000 * u.mul(u) + 
            96784180000000000 * u.mul(u).mul(u) - 186288060000000000 * u.mul(u).mul(u).mul(u) +
            278887070000000000 * u.mul(u).mul(u).mul(u).mul(u) - 1135203980000000000 * u.mul(u).mul(u).mul(u).mul(u).mul(u) +
            1488515870000000000 * u.mul(u).mul(u).mul(u).mul(u).mul(u).mul(u) - 822152230000000000 * u.mul(u).mul(u).mul(u).mul(u).mul(u).mul(u).mul(u) +
            170872770000000000 * u.mul(u).mul(u).mul(u).mul(u).mul(u).mul(u).mul(u).mul(u)
        );
        
        return result.mul(exp(-x.mul(x)));
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

    /// @notice Inverse CDF approximation using numerical methods
    /// @param p Probability value
    /// @return Inverse CDF value
    function inverseCDFApproximation(int128 p) internal pure returns (int128) {
        // Use Newton-Raphson method for approximation
        int128 x = 0;
        int128 tolerance = 100000000;
        int128 maxIterations = 10;
        
        for (int128 i = 0; i < maxIterations; i = i.add(1)) {
            int128 cdf = getCDF(x);
            int128 pdf = getPDF(x);
            
            if (pdf == 0) break;
            
            int128 delta = p.sub(cdf).div(pdf);
            x = x.add(delta);
            
            if ((delta < 0 ? -delta : delta) < tolerance) break;
        }
        
        return x;
    }

    /// @notice Probability density function (PDF) of standard normal distribution
    /// @param x Input value
    /// @return PDF value
    function getPDF(int128 x) internal pure returns (int128) {
        int128 exponent = -x.mul(x).div(2);
        return exp(exponent).div(SQRT_2PI);
    }

    /// @notice Absolute value function
    /// @param x Input value
    /// @return Absolute value
    function abs(int128 x) internal pure returns (int128) {
        return x >= 0 ? x : -x;
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
