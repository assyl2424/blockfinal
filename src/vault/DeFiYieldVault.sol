// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DeFiYieldVault
 * @notice Fully compliant ERC-4626 yield-bearing vault. Wraps our underlying asset (USDC)
 * to automate yield farming. Strictly implements and respects all ERC-4626 rounding invariants.
 */
contract DeFiYieldVault is ERC4626, Ownable {
    // Fee collected on yield harvest (basis points, 100 = 1%)
    uint256 public feeBasisPoints;
    address public feeRecipient;

    event YieldHarvested(uint256 yieldAmount, uint256 feeAmount);
    event FeeConfigUpdated(address indexed recipient, uint256 fee);

    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        address initialOwner
    ) ERC20(name_, symbol_) ERC4626(asset_) Ownable(initialOwner) {
        feeRecipient = initialOwner;
        feeBasisPoints = 500; // Default 5% strategy fee
    }

    /**
     * @notice Updates the strategy fee parameters.
     */
    function updateFeeConfig(address recipient, uint256 fee) external onlyOwner {
        require(recipient != address(0), "Vault: Invalid fee recipient");
        require(fee <= 2000, "Vault: Fee capped at 20%");
        feeBasisPoints = fee;
        feeRecipient = recipient;
        emit FeeConfigUpdated(recipient, fee);
    }

    /**
     * @notice Mimics harvesting yield from external sources (such as the Lending Pool).
     * Increases the vault's assets, resulting in share price appreciation.
     * @param yieldAmount The amount of underlying assets earned and injected.
     */
    function harvestYield(uint256 yieldAmount) external onlyOwner {
        require(yieldAmount > 0, "Vault: Yield must be > 0");

        // Calculate and transfer strategy fees if active
        uint256 feeAmount = 0;
        if (feeBasisPoints > 0) {
            feeAmount = (yieldAmount * feeBasisPoints) / 10000;
            if (feeAmount > 0) {
                SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, feeRecipient, feeAmount);
            }
        }

        uint256 netYield = yieldAmount - feeAmount;
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), netYield);

        emit YieldHarvested(yieldAmount, feeAmount);
    }

    /**
     * @notice Returns the total assets held by this vault.
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
}
