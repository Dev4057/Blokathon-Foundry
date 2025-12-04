// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStrategy} from "./IStrategy.sol";
import {IPool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";
import {IAToken} from "@aave/aave-v3-core/contracts/interfaces/IAToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DataTypes} from "@aave/aave-v3-core/contracts/protocol/libraries/types/DataTypes.sol";

contract AaveStrategy is IStrategy {
    IPool public immutable aavePool;
    
    constructor(address _aavePool) {
        aavePool = IPool(_aavePool);
    }
    
    function deposit(address asset, uint256 amount) external override returns (uint256) {
        // Approve and supply to Aave
        IERC20(asset).approve(address(aavePool), amount);
        aavePool.supply(asset, amount, address(this), 0);
        
        return amount; // 1:1 shares for simplicity
    }
    
    function withdraw(address asset, uint256 shares) external override returns (uint256) {
        // Withdraw from Aave
        uint256 withdrawn = aavePool.withdraw(asset, shares, address(this));
        
        // Transfer back to caller (Diamond)
        IERC20(asset).transfer(msg.sender, withdrawn);
        
        return withdrawn;
    }
    
    function getCurrentAPY(address asset) external view override returns (uint256) {
        DataTypes.ReserveData memory reserve = aavePool.getReserveData(asset);
        return reserve.currentLiquidityRate; // Ray format (27 decimals)
    }
    
    function getBalance(address asset) external view override returns (uint256) {
        DataTypes.ReserveData memory reserve = aavePool.getReserveData(asset);
        IAToken aToken = IAToken(reserve.aTokenAddress);
        return aToken.balanceOf(address(this));
    }
    
    function name() external pure override returns (string memory) {
        return "Aave V3";
    }
}

