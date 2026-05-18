// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LendingPool.sol";

/**
 * @title LendingPoolV2
 * @notice Upgraded LendingPool implementation to demonstrate UUPS V1 -> V2 upgradeability.
 * Adds referral management feature without altering the parent state layout.
 */
contract LendingPoolV2 is LendingPool {
    // New state variable appended at the end of the storage layout to prevent storage collisions
    uint256 public referralBonusBasisPoints;
    mapping(address => address) public referrers;

    event ReferralSet(address indexed user, address indexed referrer);
    event ReferralBonusUpdated(uint256 newBonus);

    /**
     * @notice Set the referrer for a user.
     */
    function setReferrer(address user, address referrer) external onlyOwner {
        require(user != address(0) && referrer != address(0), "LendingPoolV2: Invalid address");
        require(user != referrer, "LendingPoolV2: Self referral not allowed");
        referrers[user] = referrer;
        emit ReferralSet(user, referrer);
    }

    /**
     * @notice Updates the referral bonus basis points.
     */
    function setReferralBonus(uint256 bonus) external onlyOwner {
        require(bonus <= 1000, "LendingPoolV2: Bonus exceeds 10%"); // cap at 10%
        referralBonusBasisPoints = bonus;
        emit ReferralBonusUpdated(bonus);
    }

    /**
     * @notice A V2 specific helper function returning the version string.
     */
    function getVersion() external pure returns (string memory) {
        return "V2.0.0";
    }
}
