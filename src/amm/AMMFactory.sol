// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AMM.sol";
import "../tokens/MockERC20.sol";

/**
 * @title AMMFactory
 * @notice Factory contract that deploys AMM liquidity pools deterministically (using CREATE2)
 * and deploys mock tokens (using CREATE). Satisfies advanced Solidity requirements.
 */
contract AMMFactory {
    // Maps token0 => token1 => Pool Address
    mapping(address => mapping(address => address)) public getPool;
    address[] public allPools;

    event PoolCreated(address indexed token0, address indexed token1, address pool, uint256 allPoolsLength);
    event TokenCreated(address indexed token, string name, string symbol, uint8 decimals);

    /**
     * @notice Deploys an AMM pool using CREATE2 deterministically.
     * @param tokenA Address of token A.
     * @param tokenB Address of token B.
     * @return pool The address of the deployed AMM pool.
     */
    function createPool(address tokenA, address tokenB) external returns (address pool) {
        require(tokenA != address(0) && tokenB != address(0), "AMMFactory: Zero Address");
        require(tokenA != tokenB, "AMMFactory: Identical Address");

        // Sort tokens to guarantee token0 < token1
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(getPool[token0][token1] == address(0), "AMMFactory: Pool Exists");

        // Salt is computed deterministically using the sorted token addresses
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        // Deploys the pool using CREATE2
        AMM newPool = new AMM{salt: salt}(token0, token1);
        pool = address(newPool);

        getPool[token0][token1] = pool;
        getPool[token1][token0] = pool; // Map bidirectionally
        allPools.push(pool);

        emit PoolCreated(token0, token1, pool, allPools.length);
    }

    /**
     * @notice Deploys a Mock ERC-20 token using CREATE (standard new operator).
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param decimals The number of decimals.
     * @return token The address of the newly deployed Mock token.
     */
    function createMockToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals
    ) external returns (address token) {
        // Deploys the token using CREATE
        MockERC20 newToken = new MockERC20(name, symbol, decimals);
        token = address(newToken);

        emit TokenCreated(token, name, symbol, decimals);
    }

    /**
     * @notice Returns the total number of deployed AMM pools.
     */
    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    /**
     * @notice Off-chain helper to precompute the address of a pool.
     * @param tokenA Address of token A.
     * @param tokenB Address of token B.
     * @return predictedAddress The precomputed address of the pool.
     */
    function predictPoolAddress(
        address tokenA,
        address tokenB
    ) external view returns (address predictedAddress) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        bytes memory bytecode = abi.encodePacked(
            type(AMM).creationCode,
            abi.encode(token0, token1)
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );
        
        predictedAddress = address(uint160(uint256(hash)));
    }
}
