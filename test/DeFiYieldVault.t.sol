// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/vault/DeFiYieldVault.sol";
import "../src/tokens/MockERC20.sol";

contract DeFiYieldVaultTest is Test {
    DeFiYieldVault public vault;
    MockERC20 public usdc;

    address public owner = address(0x11);
    address public user = address(0x22);
    address public feeRecipient = address(0x33);

    function setUp() public {
        vm.startPrank(owner);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        vault = new DeFiYieldVault(usdc, "DSA USDC Yield Vault", "vUSDC", owner);
        vm.stopPrank();

        usdc.mint(user, 100000 * 1e18);
        usdc.mint(owner, 100000 * 1e18); // Used for harvesting yield

        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);

        vm.prank(owner);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testVaultInitialSetup() public view {
        assertEq(address(vault.asset()), address(usdc));
        assertEq(vault.name(), "DSA USDC Yield Vault");
        assertEq(vault.symbol(), "vUSDC");
        assertEq(vault.feeRecipient(), owner);
        assertEq(vault.feeBasisPoints(), 500); // 5% default
    }

    function testDepositAndMint() public {
        vm.startPrank(user);
        
        // Deposit 1000 USDC
        uint256 shares = vault.deposit(1000 * 1e18, user);
        
        assertEq(shares, 1000 * 1e18);
        assertEq(vault.balanceOf(user), 1000 * 1e18);
        assertEq(vault.totalAssets(), 1000 * 1e18);
        
        vm.stopPrank();
    }

    function testHarvestYieldAppreciation() public {
        vm.prank(owner);
        vault.updateFeeConfig(feeRecipient, 500); // Route fee to external 0x33

        vm.prank(user);
        vault.deposit(1000 * 1e18, user);

        // Vault has 1000 USDC, 1000 shares (1 USDC = 1 share)
        // Admin harvests $100 yield
        // Vault has 5% strategy fee: 5 USDC goes to feeRecipient, 95 USDC goes to vault
        vm.prank(owner);
        vault.harvestYield(100 * 1e18);

        // Vault should have 1095 USDC total assets
        emit log_named_uint("Vault Total Assets", vault.totalAssets());
        emit log_named_uint("User Max Withdraw", vault.maxWithdraw(user));
        emit log_named_uint("User Shares Balance", vault.balanceOf(user));
        emit log_named_uint("Vault Total Supply", vault.totalSupply());

        assertEq(vault.totalAssets(), 1095 * 1e18);
        assertEq(usdc.balanceOf(owner), 100000 * 1e18 - 100 * 1e18); // Owner spent 100 USDC (95 to vault + 5 fee)
        assertEq(usdc.balanceOf(feeRecipient), 5 * 1e18);            // Fee recipient received 5 USDC

        // Shares of user are still 1000
        // Due to OZ v5 inflation attack protection (denominator + 1), maxWithdraw is exactly 1095 * 1e18 - 1
        uint256 maxRedeemAssets = vault.maxWithdraw(user);
        assertEq(maxRedeemAssets, 1095 * 1e18 - 1);
    }

    function testWithdrawAndRedeem() public {
        vm.startPrank(user);
        vault.deposit(1000 * 1e18, user);

        // Withdraw 400 USDC
        vault.withdraw(400 * 1e18, user, user);

        assertEq(vault.balanceOf(user), 600 * 1e18);
        assertEq(vault.totalAssets(), 600 * 1e18);
        assertEq(usdc.balanceOf(user), 100000 * 1e18 - 600 * 1e18);

        // Redeem all remaining shares
        vault.redeem(600 * 1e18, user, user);
        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(usdc.balanceOf(user), 100000 * 1e18);
        
        vm.stopPrank();
    }

    /**
     * @notice Test standard ERC-4626 rounding down on deposits and rounding up on withdraws.
     */
    function testERC4626RoundingCompliance() public {
        vm.prank(user);
        vault.deposit(1000 * 1e18, user);

        // Inject yield to create fractional share prices
        // Total assets = 1000 * 1e18. Shares = 1000 * 1e18.
        // Inject 1 wei of yield
        vm.startPrank(owner);
        vault.updateFeeConfig(owner, 0); // Remove fee for simple math
        usdc.mint(owner, 1);
        usdc.approve(address(vault), 1);
        vault.harvestYield(1);
        vm.stopPrank();

        // Total Assets = 1000 * 1e18 + 1. Shares = 1000 * 1e18.
        // Price per share = (1000 * 1e18 + 1) / 1000 * 1e18.
        // If a user deposits 500 * 1e18 USDC:
        // Expected shares = 500 * 1e18 * (1000 * 1e18) / (1000 * 1e18 + 1) = 499999999999999999999.5...
        // ERC-4626 requires rounding down, so it must mint exactly 499999999999999999999 shares!
        uint256 previewDeposit = vault.previewDeposit(500 * 1e18);
        assertEq(previewDeposit, 499999999999999999999);

        // If a user withdraws 500 * 1e18 USDC:
        // Expected shares to burn = 500 * 1e18 * (1000 * 1e18) / (1000 * 1e18 + 1) = 499999999999999999999.5...
        // ERC-4626 requires rounding up for withdraws, so it must burn exactly 500000000000000000000 shares!
        uint256 previewWithdraw = vault.previewWithdraw(500 * 1e18);
        assertEq(previewWithdraw, 500000000000000000000);
    }

    function testUpdateFeeConfigRoleGate() public {
        vm.prank(user);
        vm.expectRevert(); // Should revert because not owner
        vault.updateFeeConfig(feeRecipient, 1000);
    }

    function testHarvestYieldRoleGate() public {
        vm.prank(user);
        vm.expectRevert(); // Should revert because not owner
        vault.harvestYield(100 * 1e18);
    }
}
