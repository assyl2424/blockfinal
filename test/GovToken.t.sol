// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/tokens/GovToken.sol";

contract GovTokenTest is Test {
    GovToken public token;
    address public admin = address(0x11);
    address public user1 = address(0x22);
    address public user2 = address(0x33);

    // Private key for permit signature testing
    uint256 public user1PrivateKey = 0xA11CE;

    function setUp() public {
        vm.prank(admin);
        token = new GovToken("DSA Governance Token", "DSA-GOV", admin);
        user1 = vm.addr(user1PrivateKey);
    }

    function testInitialState() public view {
        assertEq(token.name(), "DSA Governance Token");
        assertEq(token.symbol(), "DSA-GOV");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), admin));
    }

    function testMintRoleGate() public {
        // Minting from admin should succeed
        vm.prank(admin);
        token.mint(user1, 1000 * 1e18);
        assertEq(token.balanceOf(user1), 1000 * 1e18);

        // Minting from user2 (no role) should revert
        vm.prank(user2);
        vm.expectRevert();
        token.mint(user2, 500 * 1e18);
    }

    function testVotingPowerDelegation() public {
        vm.startPrank(admin);
        token.mint(user1, 1000 * 1e18);
        token.mint(user2, 500 * 1e18);
        vm.stopPrank();

        // Initial voting power is zero because no delegation is set
        assertEq(token.getVotes(user1), 0);
        assertEq(token.getVotes(user2), 0);

        // User1 delegates to self
        vm.prank(user1);
        token.delegate(user1);
        assertEq(token.getVotes(user1), 1000 * 1e18);

        // User2 delegates to User1
        vm.prank(user2);
        token.delegate(user1);
        assertEq(token.getVotes(user1), 1500 * 1e18);
        assertEq(token.getVotes(user2), 0);

        // Transfer tokens and check voting power update
        vm.prank(user1);
        token.transfer(user2, 300 * 1e18);
        // User1's voting power should decrease by 300 * 1e18
        // Wait, User2 delegates to User1, so both User1 and User2's tokens are delegated to User1!
        // So User1's voting power is still 1500 * 1e18 (1000 - 300 + 500 + 300 = 1500)!
        assertEq(token.getVotes(user1), 1500 * 1e18);

        // User2 delegates to self
        vm.prank(user2);
        token.delegate(user2);
        // Now User2's voting power should be their balance: 500 + 300 = 800 * 1e18
        // User1's voting power should be their balance: 700 * 1e18
        assertEq(token.getVotes(user1), 700 * 1e18);
        assertEq(token.getVotes(user2), 800 * 1e18);
    }

    /**
     * @notice Test ERC20Permit gasless approval signature verification.
     */
    function testPermitSignature() public {
        vm.prank(admin);
        token.mint(user1, 1000 * 1e18);

        uint256 nonce = token.nonces(user1);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 value = 500 * 1e18;

        // EIP712 domain hash components
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();

        // structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline))
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                user1,
                user2,
                value,
                nonce,
                deadline
            )
        );

        // Digest to be signed
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // Sign digest with user1's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        // Call permit
        token.permit(user1, user2, value, deadline, v, r, s);

        // Verify allowance is correct
        assertEq(token.allowance(user1, user2), value);
    }

    /**
     * @notice Fuzz test to verify delegation updates.
     */
    function testDelegationFuzz(uint256 amount) public {
        // Bound amount to prevent overflow
        amount = bound(amount, 1, type(uint112).max);

        vm.startPrank(admin);
        token.mint(user1, amount);
        vm.stopPrank();

        assertEq(token.getVotes(user1), 0);

        vm.prank(user1);
        token.delegate(user1);

        assertEq(token.getVotes(user1), amount);
    }
}
