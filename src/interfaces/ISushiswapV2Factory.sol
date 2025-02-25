// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title ISushiswapV2Factory
 * @dev Interface for the SushiSwap V2 Factory contract
 */
interface ISushiswapV2Factory {
    /**
     * @dev Returns the address of a pair for tokenA and tokenB, if it has been created
     * @param tokenA The first token of the pair
     * @param tokenB The second token of the pair
     * @return pair The address of the pair
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    
    /**
     * @dev Creates a new pair for tokenA and tokenB
     * @param tokenA The first token of the pair
     * @param tokenB The second token of the pair
     * @return pair The address of the created pair
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);
    
    /**
     * @dev Returns the address that receives protocol fees
     * @return The address that receives fees
     */
    function feeTo() external view returns (address);
    
    /**
     * @dev Returns the address that can change feeTo
     * @return The address that can change feeTo
     */
    function feeToSetter() external view returns (address);
    
    /**
     * @dev Returns the address of the migrator contract
     * @return The address of the migrator
     */
    function migrator() external view returns (address);
    
    /**
     * @dev Returns the array of all pairs
     * @param index The index in the pairs array
     * @return The address of the pair
     */
    function allPairs(uint256 index) external view returns (address);
    
    /**
     * @dev Returns the total number of pairs
     * @return The total number of pairs
     */
    function allPairsLength() external view returns (uint);
} 