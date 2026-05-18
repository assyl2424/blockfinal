// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PositionNFT
 * @notice ERC-721 NFT that represents an active position in the Lending Pool.
 * The Lending Pool is granted MINTER_ROLE and BURNER_ROLE.
 */
contract PositionNFT is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 private _nextTokenId;

    constructor(
        string memory name,
        string memory symbol,
        address admin
    ) ERC721(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Mints a position NFT to a user.
     * @param to The address of the position owner.
     * @return tokenId The ID of the newly minted token.
     */
    function mint(address to) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);
    }

    /**
     * @notice Burns a position NFT.
     * @param tokenId The ID of the token to burn.
     */
    function burn(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    /**
     * @notice Returns the total number of minted NFTs.
     */
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    // Overrides required by Solidity

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
