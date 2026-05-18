// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/libraries/YulMath.sol";

contract YulMathWrapper {
    function yulSqrt(uint256 x) external pure returns (uint256) {
        return YulMath.yulSqrt(x);
    }
    
    function yulMulDiv(
        uint256 a,
        uint256 b,
        uint256 denom
    ) external pure returns (uint256) {
        return YulMath.yulMulDiv(a, b, denom);
    }
}

contract YulMathTest is Test {
    YulMathWrapper public wrapper;

    function setUp() public {
        wrapper = new YulMathWrapper();
    }

    function testSqrtUnit() public pure {
        assertEq(YulMath.yulSqrt(0), 0);
        assertEq(YulMath.yulSqrt(1), 1);
        assertEq(YulMath.yulSqrt(4), 2);
        assertEq(YulMath.yulSqrt(9), 3);
        assertEq(YulMath.yulSqrt(100), 10);
        assertEq(YulMath.yulSqrt(1000000), 1000);
    }

    function testMulDivUnit() public pure {
        assertEq(YulMath.yulMulDiv(10, 20, 2), 100);
        assertEq(YulMath.yulMulDiv(100, 5, 25), 20);
        assertEq(YulMath.yulMulDiv(0, 50, 5), 0);
    }

    function testMulDivRevertOnZeroDiv() public {
        vm.expectRevert();
        wrapper.yulMulDiv(10, 20, 0);
    }

    function testMulDivRevertOnOverflow() public {
        vm.expectRevert();
        wrapper.yulMulDiv(type(uint256).max, 2, 1);
    }

    /**
     * @notice Fuzz test to verify yulSqrt exactly matches solSqrt for all inputs.
     */
    function testSqrtFuzz(uint256 val) public pure {
        uint256 yul = YulMath.yulSqrt(val);
        uint256 sol = YulMath.solSqrt(val);
        assertEq(yul, sol, "Sqrt mismatch");
    }

    /**
     * @notice Fuzz test to verify yulMulDiv exactly matches solMulDiv for safe inputs.
     */
    function testMulDivFuzz(uint256 a, uint256 b, uint256 denom) public pure {
        vm.assume(denom != 0);
        
        // Prevent overflow to test correct execution paths
        if (a != 0) {
            vm.assume(b <= type(uint256).max / a);
        }

        uint256 yul = YulMath.yulMulDiv(a, b, denom);
        uint256 sol = YulMath.solMulDiv(a, b, denom);
        assertEq(yul, sol, "MulDiv mismatch");
    }

    /**
     * @notice Direct gas benchmark test logging comparison results.
     */
    function testGasBenchmark() public {
        uint256 value = 12345678901234567890;
        
        uint256 startGas = gasleft();
        uint256 yulResult = YulMath.yulSqrt(value);
        uint256 yulGasUsed = startGas - gasleft();

        startGas = gasleft();
        uint256 solResult = YulMath.solSqrt(value);
        uint256 solGasUsed = startGas - gasleft();

        assertEq(yulResult, solResult);
        emit log_named_uint("Gas Used by Yul Sqrt", yulGasUsed);
        emit log_named_uint("Gas Used by Sol Sqrt", solGasUsed);
        assertTrue(yulGasUsed <= solGasUsed, "Yul should be equal or more gas-efficient than pure Solidity");
        
        // MulDiv Benchmarks
        uint256 a = 987654321;
        uint256 b = 123456789;
        uint256 denom = 456789;

        startGas = gasleft();
        uint256 yulMD = YulMath.yulMulDiv(a, b, denom);
        uint256 yulMDGas = startGas - gasleft();

        startGas = gasleft();
        uint256 solMD = YulMath.solMulDiv(a, b, denom);
        uint256 solMDGas = startGas - gasleft();

        assertEq(yulMD, solMD);
        emit log_named_uint("Gas Used by Yul MulDiv", yulMDGas);
        emit log_named_uint("Gas Used by Sol MulDiv", solMDGas);
    }
}
