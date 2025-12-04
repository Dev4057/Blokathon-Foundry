// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Facet} from "../../Facet.sol";
import {YieldAggregatorBase} from "./YieldAggregatorBase.sol";
import {YieldAggregatorStorage} from "./YieldAggregatorStorage.sol";
import {IYieldAggregator} from "./IYieldAggregator.sol";

contract YieldAggregatorFacet is Facet, YieldAggregatorBase, IYieldAggregator {
    
    // User functions
    function deposit(address asset, uint256 amount) external override {
        _deposit(asset, amount);
    }
    
    function withdraw(address asset, uint256 amount) external override returns (uint256) {
        return _withdraw(asset, amount);
    }
    
    function rebalance(address asset) external override {
        _rebalance(asset);
    }
    
    // Admin functions
    function addStrategy(address asset, address strategy) external override {
        // Add onlyOwner modifier via Diamond ownership facet
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        s.assetStrategies[asset].push(
            YieldAggregatorStorage.StrategyInfo({
                strategyAddress: strategy,
                isActive: true,
                totalDeposits: 0,
                lastUpdateTime: block.timestamp
            })
        );
    }
    
    function removeStrategy(address asset, address strategy) external override {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        YieldAggregatorStorage.StrategyInfo[] storage strategies = s.assetStrategies[asset];
        
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].strategyAddress == strategy) {
                strategies[i].isActive = false;
                break;
            }
        }
    }
    
    function setRebalanceThreshold(uint256 threshold) external override {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        s.rebalanceThreshold = threshold;
    }
    
    // View functions
    function getUserBalance(address user, address asset) external view override returns (uint256) {
        return _getUserBalance(user, asset);
    }
    
    function getBestStrategy(address asset) external view override returns (address) {
        return _findBestStrategy(asset);
    }
    
    function getCurrentAPY(address asset) external view override returns (uint256) {
        return _getTotalAPY(asset);
    }
}