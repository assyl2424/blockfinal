// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/lending/LendingPool.sol";
import "../src/lending/LendingPoolV2.sol";
import "../src/tokens/PositionNFT.sol";
import "../src/oracles/PriceOracle.sol";
import "./mocks/MockV3Aggregator.sol";
import "../src/tokens/MockERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LendingPoolTest is Test {
    LendingPool public poolImpl;
    LendingPool public pool;
    PositionNFT public positionNFT;
    PriceOracle public oracle;
    MockV3Aggregator public wethFeed;
    MockV3Aggregator public usdcFeed;

    MockERC20 public weth;
    MockERC20 public usdc;

    address public admin = address(0x11);
    address public treasury = address(0x22);
    address public user = address(0x33);
    address public liquidator = address(0x44);

    function setUp() public {
        vm.startPrank(admin);

        // 1. Deploy Tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 18);

        // 2. Deploy Position NFT
        positionNFT = new PositionNFT("DSA Lending Position", "DSA-LP-NFT", admin);

        // 3. Deploy Oracle Gateway
        oracle = new PriceOracle(admin);
        wethFeed = new MockV3Aggregator(8, 3000 * 1e8); // $3000
        usdcFeed = new MockV3Aggregator(8, 1 * 1e8);    // $1
        oracle.setPriceFeed(address(weth), address(wethFeed), 3600);
        oracle.setPriceFeed(address(usdc), address(usdcFeed), 3600);

        // 4. Deploy Lending Pool Implementation
        poolImpl = new LendingPool();

        // 5. Deploy UUPS Proxy
        bytes memory initData = abi.encodeWithSelector(
            LendingPool.initialize.selector,
            address(weth),
            address(usdc),
            address(positionNFT),
            address(oracle),
            treasury,
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(poolImpl), initData);
        pool = LendingPool(address(proxy));

        // 6. Grant NFT Roles to Pool Proxy
        positionNFT.grantRole(positionNFT.MINTER_ROLE(), address(pool));
        positionNFT.grantRole(positionNFT.BURNER_ROLE(), address(pool));

        // Mint and distribute WETH/USDC
        weth.mint(user, 100 * 1e18);
        usdc.mint(user, 100000 * 1e18);
        
        // Supply USDC to the pool via supplyBorrowToken
        usdc.mint(admin, 50000 * 1e18);
        usdc.approve(address(pool), type(uint256).max);
        pool.supplyBorrowToken(50000 * 1e18);

        weth.mint(liquidator, 100 * 1e18);
        usdc.mint(liquidator, 100000 * 1e18);

        vm.stopPrank();

        // Approve pool
        vm.startPrank(user);
        weth.approve(address(pool), type(uint256).max);
        usdc.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(liquidator);
        weth.approve(address(pool), type(uint256).max);
        usdc.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function testLendingPoolInitialState() public view {
        assertEq(address(pool.collateralToken()), address(weth));
        assertEq(address(pool.borrowToken()), address(usdc));
        assertEq(address(pool.positionNFT()), address(positionNFT));
        assertEq(address(pool.priceOracle()), address(oracle));
        assertEq(pool.treasury(), treasury);
        assertEq(pool.borrowIndex(), 1e18);
    }

    function testDepositCollateral() public {
        vm.prank(user);
        uint256 tokenId = pool.depositCollateral(10 * 1e18);

        assertEq(tokenId, 1);
        assertEq(positionNFT.ownerOf(1), user);
        assertEq(pool.userNFT(user), 1);

        (uint256 collateral, uint256 principal, uint256 index) = pool.positions(1);
        assertEq(collateral, 10 * 1e18);
        assertEq(principal, 0);
        assertEq(index, 0);
    }

    function testBorrowEnforcesLTV() public {
        vm.startPrank(user);
        pool.depositCollateral(10 * 1e18); // $30000 collateral

        // Max capacity is $24000 (80% of $30000)
        // Attempt to borrow 25000 USDC should revert
        vm.expectRevert("Insufficient collateral capacity");
        pool.borrow(25000 * 1e18);

        // Borrowing 22000 USDC should succeed
        pool.borrow(22000 * 1e18);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user), 122000 * 1e18);
        (, uint256 principal, ) = pool.positions(1);
        assertEq(principal, 22000 * 1e18);
    }

    function testRepayBorrow() public {
        vm.startPrank(user);
        pool.depositCollateral(10 * 1e18);
        pool.borrow(10000 * 1e18);

        assertEq(pool.getPositionDebt(1), 10000 * 1e18);

        // Repay 5000 USDC
        pool.repay(5000 * 1e18);
        vm.stopPrank();

        assertEq(pool.getPositionDebt(1), 5000 * 1e18);
    }

    function testLinearInterestAccrual() public {
        vm.startPrank(user);
        pool.depositCollateral(10 * 1e18);
        pool.borrow(10000 * 1e18); // Accrues borrow interest
        vm.stopPrank();

        // Initial borrowIndex is 1e18
        assertEq(pool.borrowIndex(), 1e18);

        // Fast forward 1 year (365 days)
        vm.warp(block.timestamp + 365 days);

        // Accrue interest
        pool.accrueInterest();

        // Interest should be accrued. Global borrow index must increase
        assertTrue(pool.borrowIndex() > 1e18, "Index did not increase");
        assertTrue(pool.getPositionDebt(1) > 10000 * 1e18, "Debt did not grow");
    }

    function testLiquidationUnhealthyPosition() public {
        vm.startPrank(user);
        pool.depositCollateral(10 * 1e18); // $30000 collateral
        pool.borrow(22000 * 1e18); // $22000 debt
        vm.stopPrank();

        // Health factor should be healthy (e.g. > 1e18)
        assertTrue(pool.getHealthFactor(1) > 1e18);

        // Simulate ETH price crash from $3000 to $2000
        wethFeed.updateRoundData(2, 2000 * 1e8, block.timestamp, 2);

        // Now collateral value is $20000, debt is $22000
        // Health factor is definitely < 1e18 (unhealthy!)
        assertTrue(pool.getHealthFactor(1) < 1e18);

        // Liquidate debt
        // Liquidator repays 5000 USDC
        vm.prank(liquidator);
        pool.liquidate(1, 5000 * 1e18);

        // Liquidator should receive seized WETH (worth 5000 * 1.05 = 5250 USD)
        // seiedCollateral = (5000 * 1e18 * 1e8 * 1.05) / 2000 * 1e8 = 2.625 * 1e18 WETH
        assertEq(weth.balanceOf(liquidator), 102.625 * 1e18);
    }

    /**
     * @notice Tests the complete UUPS V1 -> V2 Upgrade path.
     */
    function testUUPSUpgrade() public {
        // Deploy upgraded LendingPoolV2
        vm.startPrank(admin);
        LendingPoolV2 poolV2Impl = new LendingPoolV2();

        // Perform proxy upgrade using the UUPS upgradeToAndCall API
        pool.upgradeToAndCall(address(poolV2Impl), "");
        vm.stopPrank();

        // Re-wrap the proxy address in the V2 contract instance
        LendingPoolV2 poolV2 = LendingPoolV2(address(pool));

        // Test V2 features
        assertEq(poolV2.getVersion(), "V2.0.0");

        // Verify that old states (collateralToken) are preserved perfectly
        assertEq(address(poolV2.collateralToken()), address(weth));

        // Perform administrative actions on V2
        vm.startPrank(admin);
        poolV2.setReferralBonus(500); // 5% bonus
        poolV2.setReferrer(user, liquidator);
        vm.stopPrank();

        assertEq(poolV2.referralBonusBasisPoints(), 500);
        assertEq(poolV2.referrers(user), liquidator);
    }
}
