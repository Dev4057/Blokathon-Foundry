// script/DeployAutomation.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {AutomationFacet} from "../src/facets/utilityFacets/yieldAggregator/AutomationFacet.sol";
import {GelatoAutomationFacet} from "../src/facets/utilityFacets/yieldAggregator/GelatoAutomationFacet.sol";
import {IDiamondCut} from "../src/facets/baseFacets/cut/IDiamondCut.sol";

contract DeployAutomation is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Choose ONE: Chainlink OR Gelato
        
        // ═══ OPTION A: CHAINLINK ═══
        AutomationFacet chainlinkFacet = new AutomationFacet();
        console.log("Chainlink Automation Facet:", address(chainlinkFacet));
        
        // Prepare function selectors
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = AutomationFacet.checkUpkeep.selector;
        selectors[1] = AutomationFacet.performUpkeep.selector;
        selectors[2] = AutomationFacet.configureAutomation.selector;
        selectors[3] = AutomationFacet.pauseAutomation.selector;
        selectors[4] = AutomationFacet.getRebalanceStatus.selector;
        selectors[5] = AutomationFacet.getAutomationConfig.selector;
        
        // Add to Diamond
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(chainlinkFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        IDiamondCut(diamondAddress).diamondCut(cuts, address(0), "");
        
        // Configure automation
        AutomationFacet(diamondAddress).configureAutomation(
            3600,  // 1 hour cooldown
            true   // enabled
        );
        
        console.log("Automation configured with 1 hour cooldown");
        
        vm.stopBroadcast();
    }
}