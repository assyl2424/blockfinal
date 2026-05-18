// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/tokens/GovToken.sol";
import "../src/governance/ProtocolTreasury.sol";
import "../src/governance/ProtocolGovernor.sol";

contract GovernanceTest is Test {
    GovToken public govToken;
    ProtocolTreasury public treasury;
    ProtocolGovernor public governor;
    TimelockController public timelock;

    address public admin = address(0x11);
    address public proposer = address(0x22);
    address public voter1 = address(0x33);
    address public voter2 = address(0x44);

    uint256 public constant INITIAL_SUPPLY = 1000000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);

        // 1. Deploy Governance Token
        govToken = new GovToken("DSA Gov Token", "DSA-GOV", admin);

        // 2. Deploy TimelockController
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new TimelockController(2 days, proposers, executors, admin);

        // 3. Deploy Governor
        governor = new ProtocolGovernor(
            govToken,
            timelock,
            1,      // 1 block voting delay
            10,     // 10 blocks voting period
            0       // 0 proposal threshold so anyone can propose
        );

        // 4. Deploy Treasury owned by Timelock
        treasury = new ProtocolTreasury(address(timelock));

        // 5. Setup Timelock Roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // Grant Proposer role to Governor
        timelock.grantRole(proposerRole, address(governor));
        // Grant Executor role to open (address(0))
        timelock.grantRole(executorRole, address(0));
        // Revoke admin role from admin
        timelock.revokeRole(adminRole, admin);

        // Mint and distribute tokens
        govToken.mint(proposer, 100 * 1e18);
        govToken.mint(voter1, 600 * 1e18);
        govToken.mint(voter2, 300 * 1e18);

        vm.stopPrank();

        // Set up voting delegations
        vm.prank(voter1);
        govToken.delegate(voter1);

        vm.prank(voter2);
        govToken.delegate(voter2);

        vm.prank(proposer);
        govToken.delegate(proposer);
    }

    function testGovernanceInitialSetup() public view {
        assertEq(treasury.timelock(), address(timelock));
        assertEq(governor.timelock(), address(timelock));
        assertEq(address(governor.token()), address(govToken));
    }

    function testTreasuryRestrictedToGovernance() public {
        // Direct call from user to treasury should revert
        vm.prank(voter1);
        vm.expectRevert(); // Reverts because not owned by caller (owned by Timelock)
        treasury.updateParameters(123);
    }

    function testProposalLifecycleSuccessful() public {
        // Prepare call data for treasury parameters update
        bytes memory callData = abi.encodeWithSelector(ProtocolTreasury.updateParameters.selector, 8888);

        address[] memory targets = new address[](1);
        targets[0] = address(treasury);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        string memory description = "Proposal #1: Update Treasury parameters to 8888";

        // 1. Propose
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Verify state is Pending
        assertEq(uint256(governor.state(proposalId)), 0); // 0 = Pending

        // Roll 1 block to make proposal Active
        vm.roll(block.number + 2);
        assertEq(uint256(governor.state(proposalId)), 1); // 1 = Active

        // 2. Cast Votes
        // voter1 votes FOR (support = 1)
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        // voter2 votes AGAINST (support = 0)
        vm.prank(voter2);
        governor.castVote(proposalId, 0);

        // Advance blocks past voting period (10 blocks)
        vm.roll(block.number + 11);
        assertEq(uint256(governor.state(proposalId)), 4); // 4 = Succeeded

        // 3. Queue Proposal
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), 5); // 5 = Queued

        // Warp time past timelock delay (2 days)
        vm.warp(block.timestamp + 2 days + 1 hours);

        // 4. Execute Proposal
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), 7); // 7 = Executed

        // Verify that treasury parameters were updated successfully!
        assertEq(treasury.customParameter(), 8888);
    }

    function testProposalDefeated() public {
        // Prepare call data
        bytes memory callData = abi.encodeWithSelector(ProtocolTreasury.updateParameters.selector, 9999);

        address[] memory targets = new address[](1);
        targets[0] = address(treasury);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        string memory description = "Proposal #2: Defeated Proposal";

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + 2);

        // Voter 1 (600 votes) votes AGAINST (0)
        vm.prank(voter1);
        governor.castVote(proposalId, 0);

        // Voter 2 (300 votes) votes FOR (1)
        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + 11);
        
        // State should be Defeated
        assertEq(uint256(governor.state(proposalId)), 3); // 3 = Defeated

        // Trying to queue should revert
        bytes32 descriptionHash = keccak256(bytes(description));
        vm.expectRevert();
        governor.queue(targets, values, calldatas, descriptionHash);
    }
}
