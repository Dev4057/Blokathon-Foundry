// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {YieldAggregatorStorage} from "./YieldAggregatorStorage.sol";
import {IStrategy} from "./strategies/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YieldAggregatorBase {
    
    event Deposited(address indexed user, address indexed asset, uint256 amount, address strategy);
    event Withdrawn(address indexed user, address indexed asset, uint256 amount);
    event Rebalanced(address indexed asset, address fromStrategy, address toStrategy);
    
    // Internal deposit logic
    function _deposit(address asset, uint256 amount) internal {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        require(amount > 0, "Amount must be > 0");
        
        // Transfer tokens from user
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        // Find best strategy
        address bestStrategy = _findBestStrategy(asset);
        require(bestStrategy != address(0), "No active strategy");
        
        // Approve and deposit to strategy
        IERC20(asset).approve(bestStrategy, amount);
        uint256 shares = IStrategy(bestStrategy).deposit(asset, amount);
        
        // Update user info
        YieldAggregatorStorage.UserInfo storage userInfo = s.userInfo[msg.sender][asset];
        userInfo.depositedAmount += amount;
        userInfo.shares += shares;
        userInfo.activeStrategy = bestStrategy;
        
        // Update totals
        s.totalShares[asset] += shares;
        s.totalAssets[asset] += amount;
        
        emit Deposited(msg.sender, asset, amount, bestStrategy);
    }
    
    // Internal withdraw logic
    function _withdraw(address asset, uint256 amount) internal returns (uint256) {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        YieldAggregatorStorage.UserInfo storage userInfo = s.userInfo[msg.sender][asset];
        
        require(userInfo.depositedAmount >= amount, "Insufficient balance");
        
        // Calculate shares to withdraw
        uint256 sharesToWithdraw = (userInfo.shares * amount) / userInfo.depositedAmount;
        
        // Withdraw from strategy
        address strategy = userInfo.activeStrategy;
        uint256 withdrawn = IStrategy(strategy).withdraw(asset, sharesToWithdraw);
        
        // Update user info
        userInfo.depositedAmount -= amount;
        userInfo.shares -= sharesToWithdraw;
        
        // Update totals
        s.totalShares[asset] -= sharesToWithdraw;
        s.totalAssets[asset] -= amount;
        
        // Transfer to user
        IERC20(asset).transfer(msg.sender, withdrawn);
        
        emit Withdrawn(msg.sender, asset, withdrawn);
        return withdrawn;
    }
    
    // Find best strategy by APY
    function _findBestStrategy(address asset) internal view returns (address) {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        YieldAggregatorStorage.StrategyInfo[] storage strategies = s.assetStrategies[asset];
        
        uint256 bestAPY = 0;
        address bestStrategy = address(0);
        
        for (uint256 i = 0; i < strategies.length; i++) {
            if (!strategies[i].isActive) continue;
            
            uint256 apy = IStrategy(strategies[i].strategyAddress).getCurrentAPY(asset);
            
            if (apy > bestAPY) {
                bestAPY = apy;
                bestStrategy = strategies[i].strategyAddress;
            }
        }
        
        return bestStrategy;
    }
    
    // Rebalance to better strategy
    function _rebalance(address asset) internal {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        address currentBest = s.bestStrategy[asset];
        address newBest = _findBestStrategy(asset);
        
        if (currentBest == newBest || newBest == address(0)) return;
        
        // Check if APY difference exceeds threshold
        uint256 currentAPY = IStrategy(currentBest).getCurrentAPY(asset);
        uint256 newAPY = IStrategy(newBest).getCurrentAPY(asset);
        
        uint256 apyDiff = newAPY > currentAPY ? newAPY - currentAPY : 0;
        uint256 threshold = (currentAPY * s.rebalanceThreshold) / 10000;
        
        if (apyDiff < threshold) return;
        
        // Withdraw all from current strategy
        uint256 balance = IStrategy(currentBest).getBalance(asset);
        if (balance > 0) {
            IStrategy(currentBest).withdraw(asset, balance);
            
            // Deposit to new strategy
            IERC20(asset).approve(newBest, balance);
            IStrategy(newBest).deposit(asset, balance);
        }
        
        s.bestStrategy[asset] = newBest;
        
        emit Rebalanced(asset, currentBest, newBest);
    }
    
    // View functions
    function _getUserBalance(address user, address asset) internal view returns (uint256) {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        return s.userInfo[user][asset].depositedAmount;
    }
    
    function _getTotalAPY(address asset) internal view returns (uint256) {
        address bestStrategy = _findBestStrategy(asset);
        if (bestStrategy == address(0)) return 0;
        return IStrategy(bestStrategy).getCurrentAPY(asset);
    }
}