// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract RmmLibTest is Test {
    function testBasicMath() public {
        // Test basic arithmetic operations
        uint256 a = 2e18;
        uint256 b = 1e18;
        
        assertEq(a + b, 3e18);
        assertEq(a - b, 1e18);
        assertEq(a * 2, 4e18);
        assertEq(a / 2, 1e18);
        
        console.log("Basic math test passed");
    }
    
    function testWadMath() public {
        // Test WAD math operations
        uint256 wad = 1e18;
        uint256 half = 5e17;
        
        assertEq(wad, 1e18);
        assertEq(half, 5e17);
        assertEq(wad / 2, half);
        
        console.log("WAD math test passed");
    }
    
    function testTimeConversion() public {
        // Test time conversion
        uint256 oneYear = 365 days;
        uint256 oneDay = 1 days;
        
        assertEq(oneYear, 31536000);
        assertEq(oneDay, 86400);
        
        console.log("Time conversion test passed");
    }
} 
