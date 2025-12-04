// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IYieldAggregator {
    function deposit(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external returns (uint256);
    function rebalance(address asset) external;
    
    // Admin functions
    function addStrategy(address asset, address strategy) external;
    function removeStrategy(address asset, address strategy) external;
    function setRebalanceThreshold(uint256 threshold) external;
    
    // View functions
    function getUserBalance(address user, address asset) external view returns (uint256);
    function getBestStrategy(address asset) external view returns (address);
    function getCurrentAPY(address asset) external view returns (uint256);
}