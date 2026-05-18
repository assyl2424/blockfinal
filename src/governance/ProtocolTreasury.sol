// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ProtocolTreasury
 * @notice Holds the treasury assets of the protocol. Gated strictly to be controlled by the DAO Timelock.
 */
contract ProtocolTreasury {
    using SafeERC20 for IERC20;

    address public immutable timelock;
    uint256 public customParameter;

    event FundsReleased(address indexed token, address indexed recipient, uint256 amount);
    event TransactionExecuted(address indexed target, uint256 value, bytes data);
    event ParameterUpdated(uint256 newValue);

    modifier onlyTimelock() {
        require(msg.sender == timelock, "Treasury: Only Timelock");
        _;
    }

    constructor(address _timelock) {
        require(_timelock != address(0), "Treasury: Invalid Timelock");
        timelock = _timelock;
    }

    /**
     * @notice Updates a custom parameters. Used to verify DAO transaction execution.
     */
    function updateParameters(uint256 newVal) external onlyTimelock {
        customParameter = newVal;
        emit ParameterUpdated(newVal);
    }

    // Allows the treasury to receive ETH
    receive() external payable {}

    /**
     * @notice Releases ERC20 tokens to a recipient.
     * @param token The token address.
     * @param recipient The recipient address.
     * @param amount The token amount.
     */
    function releaseFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyTimelock {
        require(recipient != address(0), "Treasury: Invalid recipient");
        IERC20(token).safeTransfer(recipient, amount);
        emit FundsReleased(token, recipient, amount);
    }

    /**
     * @notice Releases ETH to a recipient.
     * @param recipient The recipient address.
     * @param amount The ETH amount.
     */
    function releaseETH(
        address payable recipient,
        uint256 amount
    ) external onlyTimelock {
        require(recipient != address(0), "Treasury: Invalid recipient");
        require(address(this).balance >= amount, "Treasury: Insufficient ETH");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Treasury: ETH transfer failed");
        emit FundsReleased(address(0), recipient, amount);
    }

    /**
     * @notice Executes an arbitrary transaction from the treasury.
     * @param target The target contract address.
     * @param value The value of ETH to send.
     * @param data The payload call data.
     */
    function executeTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyTimelock returns (bytes memory) {
        require(target != address(0), "Treasury: Invalid target");
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        require(success, "Treasury: Transaction failed");
        emit TransactionExecuted(target, value, data);
        return returnData;
    }
}
