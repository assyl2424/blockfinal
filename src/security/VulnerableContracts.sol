// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VulnerableAMM
 * @notice Demonstrates a critical Reentrancy vulnerability.
 * Transfer of ETH is performed BEFORE updating reserves and burning shares.
 */
contract VulnerableAMM {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public reserveToken;
    uint256 public reserveETH;

    mapping(address => uint256) public lpBalances;
    uint256 public totalLP;

    constructor(address _token) {
        token = IERC20(_token);
    }

    // Fallback to receive ETH
    receive() external payable {}

    function addLiquidity(uint256 tokenAmount) external payable {
        require(tokenAmount > 0 && msg.value > 0, "Zero amounts");
        
        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        
        uint256 lpToMint = msg.value; // Simplistic LP token pricing for demo
        lpBalances[msg.sender] += lpToMint;
        totalLP += lpToMint;

        reserveToken += tokenAmount;
        reserveETH += msg.value;
    }

    /**
     * @notice Vulnerable removeLiquidity.
     * Performs external call (transfer of ETH) BEFORE updating balances/reserves.
     */
    function removeLiquidity(uint256 lpAmount) external {
        require(lpBalances[msg.sender] >= lpAmount, "Insufficient LP");
        
        // Calculate shares of pool
        uint256 ethShare = (lpAmount * address(this).balance) / totalLP;
        uint256 tokenShare = (lpAmount * token.balanceOf(address(this))) / totalLP;

        // VULNERABILITY: External call before state changes!
        (bool success, ) = msg.sender.call{value: ethShare}("");
        require(success, "ETH transfer failed");

        token.safeTransfer(msg.sender, tokenShare);

        // State changes occur after external interaction!
        unchecked {
            lpBalances[msg.sender] -= lpAmount;
            totalLP -= lpAmount;
            reserveToken -= tokenShare;
            reserveETH -= ethShare;
        }
    }
}

/**
 * @title VulnerableVault
 * @notice Demonstrates a critical Access Control bypass vulnerability.
 * Administrative minting function lacks any owner or role verification.
 */
contract VulnerableVault {
    IERC20 public asset;
    mapping(address => uint256) public balances;
    uint256 public totalShares;

    constructor(address _asset) {
        asset = IERC20(_asset);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Zero amount");
        asset.transferFrom(msg.sender, address(this), amount);
        
        uint256 shares = amount; // 1:1 shares for simplicity
        balances[msg.sender] += shares;
        totalShares += shares;
    }

    /**
     * @notice Vulnerable mintShares.
     * Intended to be an admin-only back-up or emergency mint function,
     * but the developer forgot to add an onlyOwner modifier!
     */
    function mintShares(address to, uint256 amount) external {
        // VULNERABILITY: Gated check (onlyOwner/onlyRole) is missing!
        balances[to] += amount;
        totalShares += amount;
    }

    function withdraw(uint256 shares) external {
        require(balances[msg.sender] >= shares, "Insufficient shares");
        balances[msg.sender] -= shares;
        totalShares -= shares;
        
        asset.transfer(msg.sender, shares);
    }
}
