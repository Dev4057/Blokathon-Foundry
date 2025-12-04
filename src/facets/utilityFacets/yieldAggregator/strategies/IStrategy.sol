// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrategy {
    function deposit(address asset, uint256 amount) external returns (uint256 shares);
    function withdraw(address asset, uint256 shares) external returns (uint256 amount);
    function getCurrentAPY(address asset) external view returns (uint256);
    function getBalance(address asset) external view returns (uint256);
    function name() external pure returns (string memory);
}