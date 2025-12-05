// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/baseFacets/ownership/OwnershipFacet.sol";
import {YieldAggregatorFacet} from "src/facets/utilityFacets/yieldAggregator/YieldAggregatorFacet.sol";
import {GelatoAutomationFacet} from "src/facets/utilityFacets/yieldAggregator/GelatoAutomationFacet.sol";
import {AaveV3Facet} from "src/facets/utilityFacets/aaveV3/AaveV3Facet.sol";
import {AaveStrategy} from "src/facets/utilityFacets/yieldAggregator/strategies/AaveStrategy.sol";
import {CompoundStrategy} from "src/facets/utilityFacets/yieldAggregator/strategies/CompoundStrategy.sol";

/**
 * @title DeployTestnet
 * @notice Complete deployment script for Sepolia testnet
 * @dev Deploys Diamond + All Facets + Multiple Strategies
 */
contract DeployTestnet is Script {
    
    // ═══════════════════════════════════════════════════════════════
    // SEPOLIA TESTNET ADDRESSES
    // ═══════════════════════════════════════════════════════════════
    
    address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant SEPOLIA_AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant SEPOLIA_GELATO_OPS = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F;
    
    // ═══════════════════════════════════════════════════════════════
    // MAIN DEPLOYMENT
    // ═══════════════════════════════════════════════════════════════
    
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        
    
        console.log("   SEPOLIA TESTNET DEPLOYMENT");
     
        console.log("Deployer:", deployer);
        console.log("Network: Sepolia");
        console.log("");
        
        vm.startBroadcast(privateKey);
        
        // ────────────────────────────────────────────────────────────
        // STEP 1: Deploy Base Facets
        // ────────────────────────────────────────────────────────────
        console.log("[1/7] Deploying Base Facets...");
        
        DiamondCutFacet dCut = new DiamondCutFacet();
        console.log("  DiamondCutFacet:", address(dCut));
        
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        console.log("  DiamondLoupeFacet:", address(dLoupe));
        
        OwnershipFacet ownerF = new OwnershipFacet();
        console.log("  OwnershipFacet:", address(ownerF));
        console.log("");
        
        // ────────────────────────────────────────────────────────────
        // STEP 2: Prepare Base Cuts
        // ────────────────────────────────────────────────────────────
        console.log("[2/7] Preparing Diamond with Base Facets...");
        
        IDiamondCut.FacetCut[] memory baseCuts = new IDiamondCut.FacetCut[](3);
        
        baseCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(dCut),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForDiamondCut()
        });
        
        baseCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(dLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForDiamondLoupe()
        });
        
        baseCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownerF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForOwnership()
        });
        
        // ────────────────────────────────────────────────────────────
        // STEP 3: Deploy Diamond
        // ────────────────────────────────────────────────────────────
        Diamond diamond = new Diamond(deployer, baseCuts);
        console.log("  Diamond:", address(diamond));
        console.log("");
        
        // ────────────────────────────────────────────────────────────
        // STEP 4: Deploy Utility Facets
        // ────────────────────────────────────────────────────────────
        console.log("[3/7] Deploying Utility Facets...");
        
        YieldAggregatorFacet yieldFacet = new YieldAggregatorFacet();
        console.log("  YieldAggregatorFacet:", address(yieldFacet));
        
        GelatoAutomationFacet gelatoFacet = new GelatoAutomationFacet();
        console.log("  GelatoAutomationFacet:", address(gelatoFacet));
        
        AaveV3Facet aaveFacet = new AaveV3Facet();
        console.log("  AaveV3Facet:", address(aaveFacet));
        console.log("");
        
        // ────────────────────────────────────────────────────────────
        // STEP 5: Add Utility Facets to Diamond
        // ────────────────────────────────────────────────────────────
        console.log("[4/7] Adding Utility Facets to Diamond...");
        
        IDiamondCut.FacetCut[] memory utilityCuts = new IDiamondCut.FacetCut[](3);
        
        utilityCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(yieldFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForYieldAggregator()
        });
        
        utilityCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(gelatoFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForGelato()
        });
        
        utilityCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(aaveFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForAave()
        });
        
        IDiamondCut(address(diamond)).diamondCut(utilityCuts, address(0), "");
        console.log("  Utility facets added");
        console.log("");
        
        // ────────────────────────────────────────────────────────────
        // STEP 6: Deploy Strategies
        // ────────────────────────────────────────────────────────────
        console.log("[5/7] Deploying Strategies...");
        
        AaveStrategy aaveStrategy = new AaveStrategy(SEPOLIA_AAVE_POOL);
        console.log("  Aave Strategy:", address(aaveStrategy));
        
        CompoundStrategy compoundStrategy = new CompoundStrategy();
        console.log("  Compound Strategy:", address(compoundStrategy));
        console.log("");
        
        // ────────────────────────────────────────────────────────────
        // STEP 7: Configure Yield Aggregator
        // ────────────────────────────────────────────────────────────
        console.log("[6/7] Configuring Yield Aggregator...");
        
        YieldAggregatorFacet(address(diamond)).addStrategy(SEPOLIA_USDC, address(aaveStrategy));
        console.log("  Aave strategy registered");
        
        YieldAggregatorFacet(address(diamond)).addStrategy(SEPOLIA_USDC, address(compoundStrategy));
        console.log("  Compound strategy registered");
        
        YieldAggregatorFacet(address(diamond)).setRebalanceThreshold(50);
        console.log("  Rebalance threshold: 0.5%");
        console.log("");
        
        // ────────────────────────────────────────────────────────────
        // STEP 8: Configure Gelato Automation
        // ────────────────────────────────────────────────────────────
        console.log("[7/7] Configuring Gelato Automation...");
        
        GelatoAutomationFacet(address(diamond)).configureGelatoAutomation(
            3600, // 1 hour cooldown
            true, // enabled
            SEPOLIA_GELATO_OPS
        );
        console.log("  Automation enabled (1 hour cooldown)");
        console.log("");
        
        vm.stopBroadcast();
        
        // ────────────────────────────────────────────────────────────
        // DEPLOYMENT SUMMARY
        // ────────────────────────────────────────────────────────────
      
        console.log("   DEPLOYMENT COMPLETE!");
    
        console.log("");
        console.log("Key Addresses:");
        console.log("  Diamond:           ", address(diamond));
        console.log("  Aave Strategy:     ", address(aaveStrategy));
        console.log("  Compound Strategy: ", address(compoundStrategy));
        console.log("");
        console.log("Configuration:");
        console.log("  Strategies:        2 (Aave, Compound)");
        console.log("  Rebalance Threshold: 0.5%");
        console.log("  Automation:        Enabled (Gelato)");
        console.log("");
        console.log("Next Steps:");
        console.log("1. Verify contracts on Etherscan");
        console.log("2. Test deposit/withdraw");
        console.log("3. Monitor Gelato automation");
        console.log("");
        console.log("Etherscan Links:");
        console.log("  https://sepolia.etherscan.io/address/", address(diamond));
        console.log("");
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SELECTOR HELPERS
    // ═══════════════════════════════════════════════════════════════
    
    function getSelectorsForDiamondCut() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;
        return selectors;
    }
    
    function getSelectorsForDiamondLoupe() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;
        selectors[4] = DiamondLoupeFacet.supportsInterface.selector;
        return selectors;
    }
    
    function getSelectorsForOwnership() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = OwnershipFacet.owner.selector;
        selectors[1] = OwnershipFacet.transferOwnership.selector;
        return selectors;
    }
    
    function getSelectorsForYieldAggregator() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = YieldAggregatorFacet.deposit.selector;
        selectors[1] = YieldAggregatorFacet.withdraw.selector;
        selectors[2] = YieldAggregatorFacet.rebalance.selector;
        selectors[3] = YieldAggregatorFacet.addStrategy.selector;
        selectors[4] = YieldAggregatorFacet.removeStrategy.selector;
        selectors[5] = YieldAggregatorFacet.setRebalanceThreshold.selector;
        selectors[6] = YieldAggregatorFacet.getUserBalance.selector;
        selectors[7] = YieldAggregatorFacet.getBestStrategy.selector;
        selectors[8] = YieldAggregatorFacet.getCurrentAPY.selector;
        return selectors;
    }
    
    function getSelectorsForGelato() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = GelatoAutomationFacet.checker.selector;
        selectors[1] = GelatoAutomationFacet.executeRebalance.selector;
        selectors[2] = GelatoAutomationFacet.configureGelatoAutomation.selector;
        selectors[3] = GelatoAutomationFacet.pauseGelatoAutomation.selector;
        selectors[4] = GelatoAutomationFacet.getAutomationConfig.selector;
        return selectors;
    }
    
    function getSelectorsForAave() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = AaveV3Facet.getReserveData.selector;
        selectors[1] = AaveV3Facet.lend.selector;
        selectors[2] = AaveV3Facet.withdrawFromAave.selector;
        return selectors;
    }
}