// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStrategy} from "./IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CompoundStrategy
 * @notice Mock Compound V3 integration for yield aggregation
 * @dev Simplified for testing - returns mock APY for demonstration
 */
contract CompoundStrategy is IStrategy {
    
    // Mock APY for testing (6% = 600 basis points)
    uint256 private constant MOCK_APY = 600;
    
    // Track balances
    mapping(address => uint256) private balances;
    
    // Events
    event Deposited(address indexed asset, uint256 amount);
    event Withdrawn(address indexed asset, uint256 amount);
    
    /**
     * @notice Deposit assets into Compound
     * @param asset Token address
     * @param amount Amount to deposit
     * @return shares Amount of shares (1:1 for simplicity)
     */
    function deposit(address asset, uint256 amount) 
        external 
        override 
        returns (uint256 shares) 
    {
        require(amount > 0, "Amount must be > 0");
        
        // Transfer tokens from caller (Diamond)
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        
        // Update balance
        balances[asset] += amount;
        
        emit Deposited(asset, amount);
        
        // Return 1:1 shares
        return amount;
    }
    
    /**
     * @notice Withdraw assets from Compound
     * @param asset Token address
     * @param shares Amount of shares to withdraw
     * @return amount Actual amount withdrawn
     */
    function withdraw(address asset, uint256 shares) 
        external 
        override 
        returns (uint256 amount) 
    {
        require(shares > 0, "Shares must be > 0");
        require(balances[asset] >= shares, "Insufficient balance");
        
        // Update balance
        balances[asset] -= shares;
        
        // Transfer tokens back to caller (Diamond)
        IERC20(asset).transfer(msg.sender, shares);
        
        emit Withdrawn(asset, shares);
        
        return shares;
    }
    
    /**
     * @notice Get current APY for asset
     * @dev Returns mock 6% APY for testing
     * @param asset Token address (unused in mock)
     * @return apy Current APY in basis points (600 = 6%)
     */
    function getCurrentAPY(address asset) 
        external 
        pure 
        override 
        returns (uint256) 
    {
        // Silence unused variable warning
        asset;
        
        // Return mock 6% APY
        return MOCK_APY;
    }
    
    /**
     * @notice Get balance of asset in strategy
     * @param asset Token address
     * @return balance Current balance
     */
    function getBalance(address asset) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return balances[asset];
    }
    
    /**
     * @notice Get strategy name
     * @return name Strategy identifier
     */
    function name() 
        external 
        pure 
        override 
        returns (string memory) 
    {
        return "Compound V3";
    }
}