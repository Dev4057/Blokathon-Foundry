// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Diamond} from "../src/Diamond.sol";
import {YieldAggregatorFacet} from "../src/facets/utilityFacets/yieldAggregator/YieldAggregatorFacet.sol";
import {AaveStrategy} from "../src/facets/utilityFacets/yieldAggregator/strategies/AaveStrategy.sol";
import {IDiamondCut} from "../src/facets/baseFacets/cut/IDiamondCut.sol";

contract DeployYieldAggregator is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ANVIL");
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS"); // Set this after initial deploy
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy YieldAggregatorFacet
        YieldAggregatorFacet yieldFacet = new YieldAggregatorFacet();
        console.log("YieldAggregatorFacet deployed:", address(yieldFacet));
        
        // 2. Deploy AaveStrategy
        address aavePoolAddress = 0x... // Get from chain
        AaveStrategy aaveStrategy = new AaveStrategy(aavePoolAddress);
        console.log("AaveStrategy deployed:", address(aaveStrategy));
        
        // 3. Prepare DiamondCut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = YieldAggregatorFacet.deposit.selector;
        selectors[1] = YieldAggregatorFacet.withdraw.selector;
        selectors[2] = YieldAggregatorFacet.rebalance.selector;
        selectors[3] = YieldAggregatorFacet.addStrategy.selector;
        selectors[4] = YieldAggregatorFacet.removeStrategy.selector;
        selectors[5] = YieldAggregatorFacet.setRebalanceThreshold.selector;
        selectors[6] = YieldAggregatorFacet.getUserBalance.selector;
        selectors[7] = YieldAggregatorFacet.getCurrentAPY.selector;
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(yieldFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // 4. Execute DiamondCut
        Diamond diamond = Diamond(payable(diamondAddress));
        IDiamondCut(diamondAddress).diamondCut(cuts, address(0), "");
        
        console.log("YieldAggregator facet added to Diamond");
        
        vm.stopBroadcast();
    }
}