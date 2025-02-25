// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FutarchyRandomFailure
 * @notice Contract to handle random failure checks for futarchy proposals
 */
contract FutarchyRandomFailure is Ownable {
    // Default failure probability in basis points (5% = 500)
    uint256 public failureProbability = 500;
    
    // Mapping to store random failure check results
    mapping(bytes32 => bool) private randomFailureResults;
    
    // Mapping to track which condition IDs have been processed
    mapping(bytes32 => bool) private processedConditions;
    
    // Events
    event RandomFailureRequested(bytes32 indexed conditionId, uint256 timestamp);
    event RandomFailureResult(bytes32 indexed conditionId, bool failed);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Set the failure probability
     * @param _failureProbability New failure probability in basis points (0-10000)
     */
    function setFailureProbability(uint256 _failureProbability) external onlyOwner {
        require(_failureProbability <= 10000, "Probability must be <= 10000");
        failureProbability = _failureProbability;
    }
    
    /**
     * @notice Request a random failure check for a condition
     * @param conditionId The condition ID to check
     */
    function requestRandomFailureCheck(bytes32 conditionId) external {
        require(!processedConditions[conditionId], "Condition already processed");
        
        // Mark as processed
        processedConditions[conditionId] = true;
        
        // Generate pseudorandom value using block data
        uint256 randomValue = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    conditionId
                )
            )
        ) % 10000;
        
        // Set result based on probability
        bool failed = randomValue < failureProbability;
        randomFailureResults[conditionId] = failed;
        
        emit RandomFailureRequested(conditionId, block.timestamp);
        emit RandomFailureResult(conditionId, failed);
    }
    
    /**
     * @notice Check if a proposal should fail due to random check
     * @param conditionId The condition ID to check
     * @return true if the proposal should fail, false otherwise
     */
    function shouldProposalFail(bytes32 conditionId) external view returns (bool) {
        require(processedConditions[conditionId], "Condition not processed");
        return randomFailureResults[conditionId];
    }
    
    /**
     * @notice Check if a condition has been processed
     * @param conditionId The condition ID to check
     * @return true if the condition has been processed
     */
    function isConditionProcessed(bytes32 conditionId) external view returns (bool) {
        return processedConditions[conditionId];
    }
} 