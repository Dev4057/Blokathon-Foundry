

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Diamond} from "../src/Diamond.sol";
import {YieldAggregatorFacet} from "../src/facets/utilityFacets/yieldAggregator/YieldAggregatorFacet.sol";
import {AaveStrategy} from "../src/facets/utilityFacets/yieldAggregator/strategies/AaveStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YieldAggregatorTest is Test {
    Diamond diamond;
    YieldAggregatorFacet yieldAgg;
    AaveStrategy aaveStrategy;
    
    address USDC = 0x... // Testnet USDC
    address AAVE_POOL = 0x... // Testnet Aave
    
    address user1 = address(0x1);
    
    function setUp() public {
        // Deploy diamond
        diamond = new Diamond(address(this));
        
        // Deploy components
        yieldAgg = new YieldAggregatorFacet();
        aaveStrategy = new AaveStrategy(AAVE_POOL);
        
        // Add facet to diamond (simplified)
        // Use DiamondCut here
        
        // Setup strategy
        YieldAggregatorFacet(address(diamond)).addStrategy(USDC, address(aaveStrategy));
        YieldAggregatorFacet(address(diamond)).setRebalanceThreshold(50); // 0.5%
    }
    
    function testDeposit() public {
        uint256 amount = 1000e6; // 1000 USDC
        
        // Give user1 USDC
        deal(USDC, user1, amount);
        
        vm.startPrank(user1);
        
        // Approve diamond
        IERC20(USDC).approve(address(diamond), amount);
        
        // Deposit
        YieldAggregatorFacet(address(diamond)).deposit(USDC, amount);
        
        // Check balance
        uint256 balance = YieldAggregatorFacet(address(diamond)).getUserBalance(user1, USDC);
        assertEq(balance, amount);
        
        vm.stopPrank();
    }
}