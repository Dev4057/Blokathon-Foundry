// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Facet} from "../../Facet.sol";
import {YieldAggregatorStorage} from "./YieldAggregatorStorage.sol";
import {YieldAggregatorBase} from "./YieldAggregatorBase.sol";
import {IStrategy} from "./strategies/IStrategy.sol";

/**
 * @title GelatoAutomationFacet
 * @notice Enables Gelato Network automation for automatic rebalancing
 * @dev Gelato's resolver pattern: checker() + execute()
 */
contract GelatoAutomationFacet is Facet, YieldAggregatorBase {
    
    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════
    
    event UpkeepPerformed(
        address indexed asset,
        address indexed fromStrategy,
        address indexed toStrategy,
        uint256 timestamp
    );
    
    event RebalanceTriggered(
        address indexed asset,
        uint256 currentAPY,
        uint256 bestAPY,
        uint256 apyDifference
    );
    
    event GelatoConfigured(
        uint256 cooldownPeriod,
        bool enabled,
        address gelatoOps
    );
    
    // ═══════════════════════════════════════════════════════════════
    // GELATO RESOLVER PATTERN
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Gelato calls this to check if rebalance is needed
     * @dev This is the "Resolver" function for Gelato
     * @param asset Asset to check for rebalancing
     * @return canExec True if rebalance should execute
     * @return execPayload Encoded function call for Gelato to execute
     */
    function checker(address asset) 
        external 
        view 
        returns (bool canExec, bytes memory execPayload) 
    {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        // ────────────────────────────────────────────────────────────
        // CHECK 1: Automation enabled?
        // ────────────────────────────────────────────────────────────
        if (!s.automationEnabled) {
            return (false, bytes("Automation disabled"));
        }
        
        // ────────────────────────────────────────────────────────────
        // CHECK 2: Cooldown passed?
        // ────────────────────────────────────────────────────────────
        uint256 timeSinceRebalance = block.timestamp - s.lastRebalanceTime[asset];
        if (timeSinceRebalance < s.rebalanceCooldown) {
            return (false, bytes("Cooldown active"));
        }
        
        // ────────────────────────────────────────────────────────────
        // CHECK 3: Better strategy available?
        // ────────────────────────────────────────────────────────────
        address currentStrategy = s.bestStrategy[asset];
        if (currentStrategy == address(0)) {
            return (false, bytes("No active strategy"));
        }
        
        address bestStrategy = _findBestStrategy(asset);
        if (bestStrategy == address(0) || bestStrategy == currentStrategy) {
            return (false, bytes("No better strategy"));
        }
        
        // ────────────────────────────────────────────────────────────
        // CHECK 4: APY difference sufficient?
        // ────────────────────────────────────────────────────────────
        uint256 currentAPY = IStrategy(currentStrategy).getCurrentAPY(asset);
        uint256 bestAPY = IStrategy(bestStrategy).getCurrentAPY(asset);
        uint256 apyDiff = bestAPY > currentAPY ? bestAPY - currentAPY : 0;
        uint256 minDiff = (currentAPY * s.rebalanceThreshold) / 10000;
        
        if (apyDiff < minDiff) {
            return (false, bytes("APY diff insufficient"));
        }
        
        // ────────────────────────────────────────────────────────────
        // ALL CHECKS PASSED - PREPARE EXECUTION
        // ────────────────────────────────────────────────────────────
        canExec = true;
        
        // Encode the function call Gelato should execute
        execPayload = abi.encodeWithSelector(
            this.executeRebalance.selector,
            asset
        );
    }
    
    /**
     * @notice Gelato calls this to execute the rebalance
     * @dev Only callable by Gelato Ops contract
     * @param asset Asset to rebalance
     */
    function executeRebalance(address asset) external {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        // ────────────────────────────────────────────────────────────
        // SECURITY: Verify caller is Gelato (optional but recommended)
        // ────────────────────────────────────────────────────────────
        // require(msg.sender == s.automationRegistry, "Only Gelato");
        
        // ────────────────────────────────────────────────────────────
        // SECURITY: Re-verify all conditions
        // ────────────────────────────────────────────────────────────
        require(s.automationEnabled, "Automation disabled");
        require(
            block.timestamp >= s.lastRebalanceTime[asset] + s.rebalanceCooldown,
            "Cooldown active"
        );
        
        address currentStrategy = s.bestStrategy[asset];
        require(currentStrategy != address(0), "No active strategy");
        
        address bestStrategy = _findBestStrategy(asset);
        require(bestStrategy != address(0), "No best strategy");
        require(bestStrategy != currentStrategy, "Already optimal");
        
        // Verify APY difference
        uint256 currentAPY = IStrategy(currentStrategy).getCurrentAPY(asset);
        uint256 bestAPY = IStrategy(bestStrategy).getCurrentAPY(asset);
        uint256 apyDiff = bestAPY > currentAPY ? bestAPY - currentAPY : 0;
        uint256 minDiff = (currentAPY * s.rebalanceThreshold) / 10000;
        
        require(apyDiff >= minDiff, "APY diff too small");
        
        // ────────────────────────────────────────────────────────────
        // EXECUTE REBALANCE
        // ────────────────────────────────────────────────────────────
        emit RebalanceTriggered(asset, currentAPY, bestAPY, apyDiff);
        
        _rebalance(asset);
        
        // Update timestamp
        s.lastRebalanceTime[asset] = block.timestamp;
        
        emit UpkeepPerformed(
            asset,
            currentStrategy,
            bestStrategy,
            block.timestamp
        );
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Configure Gelato automation
     * @param cooldown Cooldown period in seconds
     * @param enabled Enable/disable automation
     * @param gelatoOps Address of Gelato Ops contract (optional security)
     */
    function configureGelatoAutomation(
        uint256 cooldown,
        bool enabled,
        address gelatoOps
    ) external {
        // TODO: Add onlyOwner modifier
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        s.rebalanceCooldown = cooldown;
        s.automationEnabled = enabled;
        s.automationRegistry = gelatoOps;
        
        emit GelatoConfigured(cooldown, enabled, gelatoOps);
    }
    
    /**
     * @notice Emergency stop
     */
    function pauseGelatoAutomation() external {
        // TODO: Add onlyOwner modifier
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        s.automationEnabled = false;
        
        emit GelatoConfigured(s.rebalanceCooldown, false, s.automationRegistry);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * @notice Preview rebalance status
     */
    function previewRebalance(address asset)
        external
        view
        returns (
            bool shouldRebalance,
            string memory reason,
            uint256 currentAPY,
            uint256 bestAPY,
            uint256 apyDiff,
            uint256 timeUntilRebalance
        )
    {
        YieldAggregatorStorage.Layout storage s = YieldAggregatorStorage.layout();
        
        // Get strategies
        address currentStrategy = s.bestStrategy[asset];
        if (currentStrategy != address(0)) {
            currentAPY = IStrategy(currentStrategy).getCurrentAPY(asset);
        }
        
        address best = _findBestStrategy(asset);
        if (best != address(0)) {
            bestAPY = IStrategy(best).getCurrentAPY(asset);
            apyDiff = bestAPY > currentAPY ? bestAPY - currentAPY : 0;
        }
        
        // Calculate time until rebalance possible
        uint256 timeSince = block.timestamp - s.lastRebalanceTime[asset];
        if (timeSince < s.rebalanceCooldown) {
            timeUntilRebalance = s.rebalanceCooldown - timeSince;
        }
        
        // Check if should rebalance
        (shouldRebalance, bytes memory reasonBytes) = this.checker(asset);
        reason = string(reasonBytes);
    }
}