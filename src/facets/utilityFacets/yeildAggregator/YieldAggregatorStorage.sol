/*
    What this basically does is it does not do any action it actualy stores the data in a perfect way for the yeild aggregator 

    1) It basically stores which user deposited how much 
    2) Which strategy each user is using 
    3) Which strategies exists for each asset 
    4) Which strategy has the best APY
    
 */





// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library YieldAggregatorStorage {
    bytes32 constant STORAGE_POSITION = keccak256("yield.aggregator.storage");
    
    struct UserInfo {
        uint256 depositedAmount;
        uint256 shares;
        address activeStrategy;
    }
    
    struct StrategyInfo {
        address strategyAddress;
        bool isActive;
        uint256 totalDeposits;
        uint256 lastUpdateTime;
    }
    
    struct Layout {
        // User data
        mapping(address => mapping(address => UserInfo)) userInfo; // user => asset => info
        
        // Strategy management
        mapping(address => StrategyInfo[]) assetStrategies; // asset => strategies
        mapping(address => address) bestStrategy; // asset => best strategy address
        mapping(address => uint256) lastRebalanceTime;  // asset => timestamp
        uint256 rebalanceCooldown;                      // Minimum time between rebalances
        address automationRegistry;                      // Chainlink/Gelato registry
        bool automationEnabled;                          // Master switch
        
        // Protocol addresses
        address aavePool;
        address compoundComptroller;
        
        // Totals
        mapping(address => uint256) totalShares;
        mapping(address => uint256) totalAssets;
        
        // Config
        uint256 rebalanceThreshold; // Min APY diff to trigger rebalance (in basis points)
    }
    
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}