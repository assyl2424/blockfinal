// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../src/oracles/PriceOracle.sol";
import "../src/amm/AMMFactory.sol";
import "../src/amm/AMM.sol";

contract ForkTest is Test {
    PriceOracle public oracle;
    AMMFactory public factory;

    // Production Ethereum Mainnet Addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant CHAINLINK_WETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    address public admin = address(0x11);

    function setUp() public {
        // Spin up a live mainnet fork dynamically via PublicNode
        string memory rpcUrl = "https://ethereum.publicnode.com";
        vm.createSelectFork(rpcUrl);

        vm.startPrank(admin);
        oracle = new PriceOracle(admin);
        factory = new AMMFactory();
        vm.stopPrank();
    }

    /**
     * @notice Fork Test 1: Verifies integration with real production WETH/USDC ERC20 contracts.
     */
    function testForkERC20Metadata() public view {
        IERC20Metadata wethContract = IERC20Metadata(WETH);
        IERC20Metadata usdcContract = IERC20Metadata(USDC);

        // Verify WETH metadata on live fork
        assertEq(wethContract.symbol(), "WETH");
        assertEq(wethContract.decimals(), 18);

        // Verify USDC metadata on live fork
        assertEq(usdcContract.symbol(), "USDC");
        assertEq(usdcContract.decimals(), 6);
    }

    /**
     * @notice Fork Test 2: Verifies integration with live Chainlink price feeds on Mainnet.
     */
    function testForkPriceOracleFeed() public {
        vm.prank(admin);
        // Register the live Mainnet WETH/USD Price feed (staleness threshold 24 hours)
        oracle.setPriceFeed(WETH, CHAINLINK_WETH_USD, 86400);

        // Fetch price through our PriceOracle contract
        uint256 wethPrice = oracle.getAssetPrice(WETH);

        emit log_named_uint("Live WETH Price in USD (8 decimals)", wethPrice);

        // Verify WETH price is valid (historically/definitely > $1000 USD)
        assertTrue(wethPrice > 1000 * 1e8, "Oracle returned invalid live price");
    }

    /**
     * @notice Fork Test 3: Deploys a real AMM pool for live WETH/USDC on the fork via CREATE2.
     */
    function testForkAMMPoolCreation() public {
        // Create pool for live WETH/USDC
        address poolAddress = factory.createPool(WETH, USDC);

        assertTrue(poolAddress != address(0), "Pool deployment failed");

        AMM pool = AMM(poolAddress);
        
        // Factory automatically sorts tokens alphabetically
        address sorted0 = WETH < USDC ? WETH : USDC;
        address sorted1 = WETH < USDC ? USDC : WETH;

        assertEq(pool.token0(), sorted0);
        assertEq(pool.token1(), sorted1);
    }
}
