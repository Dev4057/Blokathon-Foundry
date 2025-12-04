// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Facet} from "../../Facet.sol";
import {YieldAggregatorStorage} from "./YieldAggregatorStorage.sol";
import {YieldAggregatorBase} from "./YieldAggregatorBase.sol";
import {IStrategy} from "./strategies/IStrategy.sol";

contract AutomationFacet is Facet, YieldAggregatorBase {
    
    // Events matching your requirement
    event AutomationConfigured(uint256 cooldown, bool enabled);
    event UpkeepPerformed(address indexed asset, uint256 timestamp);

    // --------------------------------------------------------
    // Chainlink Automation Interface (KeeperCompatible)
    // --------------------------------------------------------

    /**
     * @notice Checks if upkeep is needed (e.g. rebalance required)
     * @dev param checkData is encoded as (address asset)
     */
    function checkUpkeep(bytes calldata checkData) 
        external 
        view 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        // Decode asset to check
        address asset = abi.decode(checkData, (address));
        
        if (!s.automationEnabled) return (false, "");
        
        // Check Cooldown
        if (block.timestamp < s.lastRebalanceTime[asset] + s.rebalanceCooldown) {
            return (false, "");
        }

        // Check Logic
        address bestStrategy = _findBestStrategy(asset);
        address currentStrategy = s.bestStrategy[asset];

        if (bestStrategy == address(0) || bestStrategy == currentStrategy) {
            return (false, "");
        }

        // Check Threshold
        uint256 currentAPY = IStrategy(currentStrategy).getCurrentAPY(asset);
        uint256 bestAPY = IStrategy(bestStrategy).getCurrentAPY(asset);
        
        uint256 diff = bestAPY > currentAPY ? bestAPY - currentAPY : 0;
        uint256 threshold = (currentAPY * s.rebalanceThreshold) / 10000;

        if (diff > threshold) {
            return (true, checkData); // Pass asset back as performData
        }
        
        return (false, "");
    }

    /**
     * @notice Performs the rebalance
     */
    function performUpkeep(bytes calldata performData) external {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        // Decode
        address asset = abi.decode(performData, (address));

        // Re-validate (Best practice for Chainlink)
        require(s.automationEnabled, "Automation disabled");
        require(block.timestamp >= s.lastRebalanceTime[asset] + s.rebalanceCooldown, "Cooldown");

        _rebalance(asset);
        
        s.lastRebalanceTime[asset] = block.timestamp;
        emit UpkeepPerformed(asset, block.timestamp);
    }

    // --------------------------------------------------------
    // Admin / Config
    // --------------------------------------------------------

    function configureAutomation(uint256 _cooldown, bool _enabled) external {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        s.rebalanceCooldown = _cooldown;
        s.automationEnabled = _enabled;
        emit AutomationConfigured(_cooldown, _enabled);
    }

    function pauseAutomation() external {
        YieldAggregatorStorage.layout().automationEnabled = false;
        emit AutomationConfigured(YieldAggregatorStorage.layout().rebalanceCooldown, false);
    }

    // --------------------------------------------------------
    // View
    // --------------------------------------------------------

    function getRebalanceStatus(address asset) external view returns (uint256 lastRebalance, uint256 cooldown) {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        return (s.lastRebalanceTime[asset], s.rebalanceCooldown);
    }

    function getAutomationConfig() external view returns (bool enabled, uint256 cooldown) {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        return (s.automationEnabled, s.rebalanceCooldown);
    }
}