// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/tokens/GovToken.sol";
import "../src/tokens/PositionNFT.sol";
import "../src/oracles/PriceOracle.sol";
import "../src/governance/ProtocolTreasury.sol";
import "../src/governance/ProtocolGovernor.sol";
import "../src/amm/AMMFactory.sol";
import "../src/lending/LendingPool.sol";
import "../src/vault/DeFiYieldVault.sol";
import "../src/tokens/MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployScript is Script {
    // Contract Instances
    GovToken public govToken;
    PositionNFT public positionNFT;
    PriceOracle public oracle;
    ProtocolTreasury public treasury;
    ProtocolGovernor public governor;
    TimelockController public timelock;
    AMMFactory public ammFactory;
    LendingPool public lendingPoolImpl;
    LendingPool public lendingPool;
    DeFiYieldVault public vault;

    // Assets (Mocked or real depending on chain)
    address public wethAddress;
    address public usdcAddress;
    address public wethFeed;
    address public usdcFeed;

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Determine Chain Configuration (Local vs Sepolia vs Mainnet)
        if (block.chainid == 31337) {
            // Local Anvil Network: Deploy mock tokens & mock price feeds
            MockERC20 mockWETH = new MockERC20("Mock Wrapped Ether", "mWETH", 18);
            MockERC20 mockUSDC = new MockERC20("Mock USD Coin", "mUSDC", 18);
            wethAddress = address(mockWETH);
            usdcAddress = address(mockUSDC);

            // Setup mock price feeds or just addresses
            wethFeed = address(0x01);
            usdcFeed = address(0x02);
        } else if (block.chainid == 421614) {
            // Arbitrum Sepolia Testnet Configuration
            wethAddress = address(uint160(0x00980b6c24546dcecc324028003072767606e669e9)); // Arbitrum Sepolia Mock WETH
            usdcAddress = address(uint160(0x0075faf114eafb1bd239e7b4e40165736644f57d6c)); // Arbitrum Sepolia Mock USDC
            wethFeed = address(uint160(0x00d30e2101a97d8b23b24e70251a6b140cf0A2d2f1));    // Arbitrum Sepolia WETH/USD feed
            usdcFeed = address(uint160(0x000167934f1bd63c870425a83c5f5c8e45447a11e9));    // Arbitrum Sepolia USDC/USD feed
        } else {
            // Base Sepolia Testnet / Default Configuration
            wethAddress = address(uint160(0x004200000000000000000000000000000000000006)); // Base Sepolia WETH
            usdcAddress = address(uint160(0x00034930ba7802fc5593b45698babfcf50c3c6f494)); // Base Sepolia USDC
            wethFeed = address(uint160(0x004adc67696ba3d2d237db6df9747ae373c550003b));    // Base Sepolia WETH/USD feed
            usdcFeed = address(uint160(0x00ab6b6b7bcd459dcda25f29e160b9b0beb1dfab1d));    // Base Sepolia USDC/USD feed
        }

        // 2. Deploy Math and Tokens Layer
        govToken = new GovToken("DSA Governance Token", "DSA-GOV", deployer);
        positionNFT = new PositionNFT("DSA Lending Position", "DSA-LP-NFT", deployer);

        // 3. Deploy Oracle Gateway
        oracle = new PriceOracle(deployer);
        if (block.chainid != 31337) {
            oracle.setPriceFeed(wethAddress, wethFeed, 86400); // 24h staleness threshold
            oracle.setPriceFeed(usdcAddress, usdcFeed, 86400); // 24h staleness threshold
        }

        // 4. Deploy Governance Infrastructure (Timelock + Governor + Treasury)
        // Define timelock settings (minDelay: 2 days)
        address[] memory proposers = new address[](0); // configured later
        address[] memory executors = new address[](1);
        executors[0] = address(0); // open execution

        timelock = new TimelockController(2 days, proposers, executors, deployer);
        
        // Deploy Treasury strictly controlled by Timelock
        treasury = new ProtocolTreasury(address(timelock));

        // Deploy Governor (7200 blocks delay = ~1 day, 50400 blocks period = ~1 week)
        governor = new ProtocolGovernor(govToken, timelock, 7200, 50400, 1000 * 1e18); // delay, period, threshold

        // Configure timelock roles to assign administration exclusively to governance
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0)); // allow open execution of queued proposals
        timelock.revokeRole(adminRole, deployer);     // burn deployer admin rights for ultimate decentralization

        // 5. Deploy custom DeFi primitives (AMM Factory)
        ammFactory = new AMMFactory();

        // 6. Deploy Upgradeable Lending Pool
        lendingPoolImpl = new LendingPool();

        bytes memory initData = abi.encodeWithSelector(
            LendingPool.initialize.selector,
            wethAddress,
            usdcAddress,
            address(positionNFT),
            address(oracle),
            address(treasury),
            address(timelock) // owner is the Timelock controller
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(lendingPoolImpl), initData);
        lendingPool = LendingPool(address(proxy));

        // Grant PositionNFT mint/burn rights to the LendingPool proxy
        positionNFT.grantRole(positionNFT.MINTER_ROLE(), address(lendingPool));
        positionNFT.grantRole(positionNFT.BURNER_ROLE(), address(lendingPool));
        positionNFT.revokeRole(positionNFT.DEFAULT_ADMIN_ROLE(), deployer); // burn admin role for security

        // 7. Deploy ERC-4626 Tokenized Yield Vault
        vault = new DeFiYieldVault(IERC20(usdcAddress), "DSA Yield Vault Shares", "DSA-YVS", address(timelock));

        // Stop broadcasting deployment txs
        vm.stopBroadcast();

        // Console log deployment addresses
        console.log("=== Deployment Completed Successfully ===");
        console.log("GovToken:          ", address(govToken));
        console.log("PositionNFT:       ", address(positionNFT));
        console.log("PriceOracle:       ", address(oracle));
        console.log("TimelockController:", address(timelock));
        console.log("ProtocolGovernor:  ", address(governor));
        console.log("ProtocolTreasury:  ", address(treasury));
        console.log("AMMFactory:        ", address(ammFactory));
        console.log("LendingPool Proxy: ", address(lendingPool));
        console.log("DeFiYieldVault:    ", address(vault));
        console.log("=========================================");
    }
}
