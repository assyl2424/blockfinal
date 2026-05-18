// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../libraries/YulMath.sol";

/**
 * @title AMM
 * @notice Constant product AMM (x * y = k) built from scratch.
 * Serves as the liquidity pool and LP token.
 */
contract AMM is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable token0;
    address public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 lpAmount);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, uint256 lpAmount, address indexed to);
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);

    error AMMInvalidPair();
    error AMMZeroAmount();
    error AMMInsufficientLiquidity();
    error AMMInsufficientSlippage();
    error AMMKInvariantFailed();

    constructor(
        address _token0,
        address _token1
    ) ERC20("DSA AMM LP Position", "DSA-LP") {
        if (_token0 == address(0) || _token1 == address(0) || _token0 == _token1) {
            revert AMMInvalidPair();
        }
        // Always sort tokens to keep token0 < token1
        (token0, token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
    }

    /**
     * @notice Adds liquidity to the pool.
     * @param amount0Max The maximum amount of token0 to deposit.
     * @param amount1Max The maximum amount of token1 to deposit.
     * @param minLP The minimum LP tokens expected to receive (slippage protection).
     * @param to The recipient of the LP tokens.
     * @return dep0 The actual amount of token0 deposited.
     * @return dep1 The actual amount of token1 deposited.
     * @return lpAmount The amount of LP tokens minted.
     */
    function addLiquidity(
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 minLP,
        address to
    ) external nonReentrant returns (uint256 dep0, uint256 dep1, uint256 lpAmount) {
        if (amount0Max == 0 || amount1Max == 0) revert AMMZeroAmount();
        
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            dep0 = amount0Max;
            dep1 = amount1Max;
            // Use YulMath for geometric mean (square root of product)
            lpAmount = YulMath.yulSqrt(dep0 * dep1);
        } else {
            // Determine optimal amounts
            uint256 optimalAmount1 = YulMath.yulMulDiv(amount0Max, _reserve1, _reserve0);
            if (optimalAmount1 <= amount1Max) {
                dep0 = amount0Max;
                dep1 = optimalAmount1;
            } else {
                uint256 optimalAmount0 = YulMath.yulMulDiv(amount1Max, _reserve0, _reserve1);
                require(optimalAmount0 <= amount0Max, "AMM: Optimal amount exceeds max");
                dep0 = optimalAmount0;
                dep1 = amount1Max;
            }
            
            // Calculate LP tokens to mint
            uint256 lp0 = YulMath.yulMulDiv(dep0, _totalSupply, _reserve0);
            uint256 lp1 = YulMath.yulMulDiv(dep1, _totalSupply, _reserve1);
            lpAmount = lp0 < lp1 ? lp0 : lp1;
        }

        if (lpAmount < minLP) revert AMMInsufficientSlippage();
        if (lpAmount == 0) revert AMMInsufficientLiquidity();

        // Checks-Effects-Interactions
        reserve0 = _reserve0 + dep0;
        reserve1 = _reserve1 + dep1;

        IERC20(token0).safeTransferFrom(msg.sender, address(this), dep0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), dep1);

        _mint(to, lpAmount);

        emit Mint(msg.sender, dep0, dep1, lpAmount);
        emit Sync(reserve0, reserve1);
    }

    /**
     * @notice Removes liquidity from the pool.
     * @param lpAmount The amount of LP tokens to burn.
     * @param minAmount0 The minimum token0 expected to receive (slippage protection).
     * @param minAmount1 The minimum token1 expected to receive (slippage protection).
     * @param to The recipient of the tokens.
     * @return amount0 The amount of token0 returned.
     * @return amount1 The amount of token1 returned.
     */
    function removeLiquidity(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        if (lpAmount == 0) revert AMMZeroAmount();
        
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 _totalSupply = totalSupply();

        amount0 = YulMath.yulMulDiv(lpAmount, _reserve0, _totalSupply);
        amount1 = YulMath.yulMulDiv(lpAmount, _reserve1, _totalSupply);

        if (amount0 < minAmount0 || amount1 < minAmount1) revert AMMInsufficientSlippage();

        // Checks-Effects-Interactions
        reserve0 = _reserve0 - amount0;
        reserve1 = _reserve1 - amount1;

        _burn(msg.sender, lpAmount);

        IERC20(token0).safeTransfer(to, amount0);
        IERC20(token1).safeTransfer(to, amount1);

        emit Burn(msg.sender, amount0, amount1, lpAmount, to);
        emit Sync(reserve0, reserve1);
    }

    /**
     * @notice Swaps tokens in the pool.
     * @param tokenIn The token being supplied to swap.
     * @param amountIn The amount of tokenIn to swap.
     * @param minAmountOut The minimum output tokens expected (slippage protection).
     * @param to The recipient of the output tokens.
     * @return amountOut The actual amount of tokens received.
     */
    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert AMMZeroAmount();
        if (tokenIn != token0 && tokenIn != token1) revert AMMInvalidPair();

        bool isToken0 = tokenIn == token0;
        (address tIn, address tOut) = isToken0 ? (token0, token1) : (token1, token0);
        (uint256 rIn, uint256 rOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);

        if (rIn == 0 || rOut == 0) revert AMMInsufficientLiquidity();

        // Calculate amountOut with 0.3% fee: amountInWithFee = amountIn * 997
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * rOut;
        uint256 denominator = (rIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;

        if (amountOut < minAmountOut) revert AMMInsufficientSlippage();

        // Checks-Effects-Interactions
        if (isToken0) {
            reserve0 = rIn + amountIn;
            reserve1 = rOut - amountOut;
        } else {
            reserve0 = rOut - amountOut;
            reserve1 = rIn + amountIn;
        }

        // Verify constant product invariant (x * y = k)
        // Ensure new_x * new_y >= old_x * old_y (accounting for rounding)
        if (reserve0 * reserve1 < rIn * rOut) {
            revert AMMKInvariantFailed();
        }

        IERC20(tIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tOut).safeTransfer(to, amountOut);

        emit Swap(msg.sender, tokenIn, amountIn, amountOut, to);
        emit Sync(reserve0, reserve1);
    }
}
