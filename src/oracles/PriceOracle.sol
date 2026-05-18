// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(
        uint80 _roundId
    ) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/**
 * @title PriceOracle
 * @notice Aggregates and verifies Chainlink Price Feeds with strict staleness and safety checks.
 */
contract PriceOracle is Ownable {
    // Mapping from asset address to its Chainlink Aggregator
    mapping(address => address) public priceFeeds;
    // Mapping from asset address to its custom staleness threshold (in seconds)
    mapping(address => uint256) public stalenessThresholds;

    event PriceFeedUpdated(address indexed asset, address indexed feed, uint256 threshold);

    error OraclePriceStale(address asset, uint256 age);
    error OraclePriceZeroOrNegative(address asset, int256 price);
    error OracleRoundIncomplete(address asset);
    error OracleMissingFeed(address asset);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Sets the price feed aggregator and staleness threshold for an asset.
     * @param asset The address of the asset (e.g., token).
     * @param feed The address of the Chainlink V3 Aggregator.
     * @param threshold The time threshold in seconds beyond which data is considered stale.
     */
    function setPriceFeed(
        address asset,
        address feed,
        uint256 threshold
    ) external onlyOwner {
        require(feed != address(0), "Invalid feed address");
        require(threshold > 0, "Invalid threshold");
        priceFeeds[asset] = feed;
        stalenessThresholds[asset] = threshold;
        emit PriceFeedUpdated(asset, feed, threshold);
    }

    /**
     * @notice Retrieves the latest verified price of an asset, formatted with 8 decimals.
     * @param asset The address of the asset.
     * @return price The verified positive price of the asset.
     */
    function getAssetPrice(address asset) external view returns (uint256 price) {
        address feed = priceFeeds[asset];
        if (feed == address(0)) {
            revert OracleMissingFeed(asset);
        }

        uint256 threshold = stalenessThresholds[asset];
        
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = AggregatorV3Interface(feed).latestRoundData();

        // Check for complete round and response validity
        if (answeredInRound < roundId) {
            revert OracleRoundIncomplete(asset);
        }
        if (updatedAt == 0) {
            revert OracleRoundIncomplete(asset);
        }
        if (answer <= 0) {
            revert OraclePriceZeroOrNegative(asset, answer);
        }

        // Check for staleness
        uint256 age = block.timestamp > updatedAt ? block.timestamp - updatedAt : 0;
        if (age > threshold) {
            revert OraclePriceStale(asset, age);
        }

        return uint256(answer);
    }
}
