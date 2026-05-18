// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/oracles/PriceOracle.sol";
import "./mocks/MockV3Aggregator.sol";

contract PriceOracleTest is Test {
    PriceOracle public oracle;
    MockV3Aggregator public wethFeed;
    MockV3Aggregator public usdcFeed;

    address public owner = address(0x11);
    address public user = address(0x22);
    address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function setUp() public {
        vm.prank(owner);
        oracle = new PriceOracle(owner);

        // 8 decimals standard for WETH/USD (e.g. $3000 = 3000 * 1e8)
        wethFeed = new MockV3Aggregator(8, 3000 * 1e8);
        
        // 8 decimals standard for USDC/USD (e.g. $1 = 1 * 1e8)
        usdcFeed = new MockV3Aggregator(8, 1 * 1e8);
    }

    function testOracleInitialState() public view {
        assertEq(oracle.owner(), owner);
    }

    function testSetPriceFeed() public {
        vm.startPrank(owner);
        oracle.setPriceFeed(weth, address(wethFeed), 3600); // 1 hour staleness
        vm.stopPrank();

        address feed = oracle.priceFeeds(weth);
        uint256 threshold = oracle.stalenessThresholds(weth);
        assertEq(feed, address(wethFeed));
        assertEq(threshold, 3600);
    }

    function testSetPriceFeedRoleGate() public {
        vm.prank(user);
        vm.expectRevert(); // Should revert with OwnableUnauthorizedAccount
        oracle.setPriceFeed(weth, address(wethFeed), 3600);
    }

    function testGetPriceValid() public {
        vm.startPrank(owner);
        oracle.setPriceFeed(weth, address(wethFeed), 3600);
        vm.stopPrank();

        // Should return price with 8 decimals (the native aggregator decimals)
        uint256 price = oracle.getAssetPrice(weth);
        assertEq(price, 3000 * 1e8);
    }

    function testGetPriceUnsupportedToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(PriceOracle.OracleMissingFeed.selector, weth)
        );
        oracle.getAssetPrice(weth);
    }

    function testGetPriceStaleRevert() public {
        vm.startPrank(owner);
        oracle.setPriceFeed(weth, address(wethFeed), 3600);
        vm.stopPrank();

        // Warp time past the 1 hour staleness window (block.timestamp + 2 hours)
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert(
            abi.encodeWithSelector(PriceOracle.OraclePriceStale.selector, weth, 2 hours)
        );
        oracle.getAssetPrice(weth);
    }

    function testGetPriceNegativeRevert() public {
        vm.startPrank(owner);
        oracle.setPriceFeed(weth, address(wethFeed), 3600);
        vm.stopPrank();

        // Set negative price answer on the feed
        wethFeed.updateRoundData(1, -100, block.timestamp, 1);

        vm.expectRevert(
            abi.encodeWithSelector(PriceOracle.OraclePriceZeroOrNegative.selector, weth, -100)
        );
        oracle.getAssetPrice(weth);
    }

    function testGetPriceZeroRevert() public {
        vm.startPrank(owner);
        oracle.setPriceFeed(weth, address(wethFeed), 3600);
        vm.stopPrank();

        // Set zero price answer on the feed
        wethFeed.updateRoundData(1, 0, block.timestamp, 1);

        vm.expectRevert(
            abi.encodeWithSelector(PriceOracle.OraclePriceZeroOrNegative.selector, weth, 0)
        );
        oracle.getAssetPrice(weth);
    }

    function testGetPriceIncompleteRoundRevert() public {
        vm.startPrank(owner);
        oracle.setPriceFeed(weth, address(wethFeed), 3600);
        vm.stopPrank();

        // Set incomplete round (answeredInRound != roundId)
        wethFeed.updateRoundData(2, 3000 * 1e8, block.timestamp, 1);

        vm.expectRevert(
            abi.encodeWithSelector(PriceOracle.OracleRoundIncomplete.selector, weth)
        );
        oracle.getAssetPrice(weth);
    }

    function testUpdateStalenessThreshold() public {
        vm.startPrank(owner);
        oracle.setPriceFeed(weth, address(wethFeed), 3600);
        oracle.setPriceFeed(weth, address(wethFeed), 7200); // Admin can update threshold
        vm.stopPrank();

        uint256 threshold = oracle.stalenessThresholds(weth);
        assertEq(threshold, 7200);
    }
}
