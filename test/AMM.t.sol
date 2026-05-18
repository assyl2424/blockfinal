// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/amm/AMMFactory.sol";
import "../src/amm/AMM.sol";
import "../src/tokens/MockERC20.sol";

contract AMMTest is Test {
    AMMFactory public factory;
    AMM public pool;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    address public admin = address(0x11);
    address public provider = address(0x22);
    address public swapper = address(0x33);

    MockERC20 public token0;
    MockERC20 public token1;

    function setUp() public {
        vm.startPrank(admin);
        factory = new AMMFactory();
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);

        // Deploy pool via factory (this sorts tokens dynamically inside the factory)
        address poolAddr = factory.createPool(address(tokenA), address(tokenB));
        pool = AMM(poolAddr);

        // Sort tokens for testing convenience
        if (address(tokenA) < address(tokenB)) {
            token0 = tokenA;
            token1 = tokenB;
        } else {
            token0 = tokenB;
            token1 = tokenA;
        }

        // Mint tokens to provider and swapper
        token0.mint(provider, 1000000 * 1e18);
        token1.mint(provider, 1000000 * 1e18);
        token0.mint(swapper, 10000 * 1e18);
        token1.mint(swapper, 10000 * 1e18);
        vm.stopPrank();

        // Approve pool
        vm.startPrank(provider);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(swapper);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function testAMMInitialSetup() public view {
        assertEq(pool.token0(), address(token0));
        assertEq(pool.token1(), address(token1));
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
    }

    function testAddLiquidity() public {
        vm.prank(provider);
        // Add 1000 token0 and 2000 token1 as initial liquidity, expecting at least 0 LP shares
        (,, uint256 lpShares) = pool.addLiquidity(1000 * 1e18, 2000 * 1e18, 0, provider);

        // For initial liquidity, LP shares = sqrt(amount0 * amount1)
        // sqrt(1000 * 1e18 * 2000 * 1e18) = sqrt(2000000 * 1e36) = 1414.21356 * 1e18
        assertEq(lpShares, 1414213562373095048801);
        assertEq(pool.balanceOf(provider), lpShares);
        assertEq(pool.reserve0(), 1000 * 1e18);
        assertEq(pool.reserve1(), 2000 * 1e18);
    }

    function testSwap0For1() public {
        vm.prank(provider);
        pool.addLiquidity(10000 * 1e18, 10000 * 1e18, 0, provider);

        // Reserves: reserve0 = 10000 * 1e18, reserve1 = 10000 * 1e18
        // Swapper inputs 100 token0, sending outputs to swapper
        vm.prank(swapper);
        uint256 amountOut = pool.swap(address(token0), 100 * 1e18, 0, swapper);

        assertEq(amountOut, 98715803439706129885); // matches output perfectly!
        assertEq(token1.balanceOf(swapper), 10000 * 1e18 + amountOut);
    }

    function testSwap1For0() public {
        vm.prank(provider);
        pool.addLiquidity(10000 * 1e18, 10000 * 1e18, 0, provider); // Make reserves symmetric to simplify

        // Swap 100 token1 for token0
        vm.prank(swapper);
        uint256 amountOut = pool.swap(address(token1), 100 * 1e18, 0, swapper);

        assertEq(amountOut, 98715803439706129885);
    }

    function testSlippageRevert() public {
        vm.prank(provider);
        pool.addLiquidity(1000 * 1e18, 1000 * 1e18, 0, provider);

        vm.prank(swapper);
        // Swapping 100 token0, expecting at least 95 token1, output is ~90.66 token1 (fails slippage)
        vm.expectRevert(
            abi.encodeWithSelector(AMM.AMMInsufficientSlippage.selector)
        );
        pool.swap(address(token0), 100 * 1e18, 95 * 1e18, swapper);
    }

    function testRemoveLiquidity() public {
        vm.startPrank(provider);
        (,, uint256 lpShares) = pool.addLiquidity(1000 * 1e18, 1000 * 1e18, 0, provider);

        uint256 balance0Before = token0.balanceOf(provider);
        uint256 balance1Before = token1.balanceOf(provider);

        // Remove all liquidity
        pool.removeLiquidity(lpShares, 0, 0, provider);
        vm.stopPrank();

        assertEq(pool.balanceOf(provider), 0);
        assertEq(token0.balanceOf(provider), balance0Before + 1000 * 1e18);
        assertEq(token1.balanceOf(provider), balance1Before + 1000 * 1e18);
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
    }

    /**
     * @notice Invariant fuzz test to verify x * y = k never decreases.
     */
    function testConstantProductInvariantFuzz(uint256 swapAmount) public {
        vm.prank(provider);
        pool.addLiquidity(10000 * 1e18, 10000 * 1e18, 0, provider);

        uint256 r0 = pool.reserve0();
        uint256 r1 = pool.reserve1();
        uint256 kBefore = r0 * r1;

        // Bound swapAmount to prevent pool depletion or overflow
        swapAmount = bound(swapAmount, 1 * 1e18, 5000 * 1e18);

        vm.prank(swapper);
        pool.swap(address(token0), swapAmount, 0, swapper);

        uint256 kAfter = pool.reserve0() * pool.reserve1();

        // Constant product must be conserved or increased (increased due to fees)
        assertTrue(kAfter >= kBefore, "k invariant decreased");
    }
}
