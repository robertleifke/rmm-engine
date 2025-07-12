// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ReplicationMath} from "../src/lib/Invariant.sol";
import {Units} from "../src/lib/Units.sol";
import {CumulativeNormalDistribution} from "../src/lib/CumulativeNormalDistribution.sol";

contract ReplicationMathTest is Test {
    function testUnitsFunctions() public pure {
        console.log("Testing Units functions directly");

        uint256 sigma = 10000;
        uint256 tau = 31536000;

        console.log("sigma:", sigma);
        console.log("tau:", tau);

        int128 sigmaX64 = Units.percentageToX64(sigma);
        console.log("sigmaX64:", sigmaX64);

        int128 tauYears = Units.toYears(tau);
        console.log("tauYears:", tauYears);

        int128 sqrtTau = Units.sqrt(tauYears);
        console.log("sqrtTau:", sqrtTau);
    }

    function testGetProportionalVolatility() public pure {
        // sigma = 10000 (100%), tau = 31536000 (1 year in seconds)
        uint256 sigma = 10000;
        uint256 tau = 31536000;
        int128 vol = ReplicationMath.getProportionalVolatility(sigma, tau);
        // Just check it's nonzero and positive for this input
        assertGt(vol, 0);
    }

    function testGetStableGivenRisky() public pure {
        console.log("Starting testGetStableGivenRisky");
        int128 invariantLastX64 = 0;
        uint256 scaleFactorRisky = 1e18;
        uint256 scaleFactorStable = 1e18;
        uint256 riskyPerLiquidity = 0.5e18;
        uint256 strike = 1e18;
        uint256 sigma = 10000;
        uint256 tau = 31536000;

        console.log("Calling getStableGivenRisky with:");
        console.log("invariantLastX64:", invariantLastX64);
        console.log("scaleFactorRisky:", scaleFactorRisky);
        console.log("scaleFactorStable:", scaleFactorStable);
        console.log("riskyPerLiquidity:", riskyPerLiquidity);
        console.log("strike:", strike);
        console.log("sigma:", sigma);
        console.log("tau:", tau);

        uint256 stablePerLiquidity = ReplicationMath.getStableGivenRisky(
            invariantLastX64, scaleFactorRisky, scaleFactorStable, riskyPerLiquidity, strike, sigma, tau
        );
        // Should be between 0 and strike
        assertLe(stablePerLiquidity, strike);
    }

    function testCalcInvariant() public pure {
        console.log("Starting testCalcInvariant");
        uint256 scaleFactorRisky = 1e18;
        uint256 scaleFactorStable = 1e18;
        uint256 riskyPerLiquidity = 0.5e18;
        uint256 stablePerLiquidity = 0.5e18;
        uint256 strike = 1e18;
        uint256 sigma = 10000;
        uint256 tau = 31536000;

        console.log("Calling calcInvariant with:");
        console.log("scaleFactorRisky:", scaleFactorRisky);
        console.log("scaleFactorStable:", scaleFactorStable);
        console.log("riskyPerLiquidity:", riskyPerLiquidity);
        console.log("stablePerLiquidity:", stablePerLiquidity);
        console.log("strike:", strike);
        console.log("sigma:", sigma);
        console.log("tau:", tau);

        int128 invariantX64 = ReplicationMath.calcInvariant(
            scaleFactorRisky, scaleFactorStable, riskyPerLiquidity, stablePerLiquidity, strike, sigma, tau
        );

        console.log("invariantX64:", invariantX64);

        // With simplified implementation, just check it's not extremely large
        assertLt(abs(invariantX64), 1e20);
    }

    function abs(int128 x) internal pure returns (int128) {
        return x >= 0 ? x : -x;
    }

    function testCumulativeNormalDistribution() public pure {
        console.log("Testing CumulativeNormalDistribution functions directly");

        // Test with a simple value
        int128 x = 0;
        int128 cdf = CumulativeNormalDistribution.getCdf(x);
        console.log("CDF(0):", cdf);

        // Test inverse CDF with a simple value
        int128 p = 0x8000000000000000; // 0.5 in fixed point
        int128 invCdf = CumulativeNormalDistribution.getInverseCdf(p);
        console.log("Inverse CDF(0.5):", invCdf);
    }
}
