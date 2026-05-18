// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library YulMath {
    /// @notice Calculates the square root of a number using inline Yul assembly (Babylonian method)
    /// @param x The number to calculate the square root of
    /// @return z The square root of x
    function yulSqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            // If x is 0, z is 0
            if iszero(x) {
                z := 0
            }
            if gt(x, 0) {
                z := x
                let y := add(div(x, 2), 1)
                for {} lt(y, z) {} {
                    z := y
                    y := div(add(div(x, y), y), 2)
                }
            }
        }
    }

    /// @notice Calculates the square root of a number using pure Solidity (Babylonian method)
    /// @param x The number to calculate the square root of
    /// @return z The square root of x
    function solSqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) {
            return 0;
        }
        z = x;
        uint256 y = (x / 2) + 1;
        while (y < z) {
            z = y;
            y = ((x / y) + y) / 2;
        }
    }

    /// @notice Calculates (a * b) / denominator with precision, reverting on overflow or zero division
    /// @param a Multiplicand
    /// @param b Multiplier
    /// @param denominator Divisor
    /// @return result The calculated value (a * b) / denominator
    function yulMulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        assembly {
            // Equivalent to require(denominator != 0)
            if iszero(denominator) {
                // Revert with custom selector or generic error
                // Store signature of "DivisionByZero()" (0x334b07fb)
                mstore(0x00, 0x334b07fb)
                revert(0x1c, 0x04)
            }

            // Calculate product of a and b
            let prod := mul(a, b)
            
            // Check for overflow (prod / a == b) unless a is zero
            if iszero(iszero(a)) {
                if iszero(eq(div(prod, a), b)) {
                    // Revert with Overflow() (0x352ecb75)
                    mstore(0x00, 0x352ecb75)
                    revert(0x1c, 0x04)
                }
            }

            result := div(prod, denominator)
        }
    }

    /// @notice Calculates (a * b) / denominator in pure Solidity, protecting against overflow and zero division
    /// @param a Multiplicand
    /// @param b Multiplier
    /// @param denominator Divisor
    /// @return result The calculated value (a * b) / denominator
    function solMulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        require(denominator != 0, "DivisionByZero");
        uint256 prod = a * b;
        if (a != 0) {
            require(prod / a == b, "Overflow");
        }
        result = prod / denominator;
    }
}
