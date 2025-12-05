// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

// Interfaces
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";

// Contracts
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/baseFacets/ownership/OwnershipFacet.sol";

import {YieldAggregatorFacet} from "src/facets/utilityFacets/yieldAggregator/YieldAggregatorFacet.sol";
import {GelatoAutomationFacet} from "src/facets/utilityFacets/yieldAggregator/GelatoAutomationFacet.sol";
import {AaveV3Facet} from "src/facets/utilityFacets/aaveV3/AaveV3Facet.sol";
import {AaveStrategy} from "src/facets/utilityFacets/yieldAggregator/strategies/AaveStrategy.sol";

contract DeployAll is Script {
    // Config (Sepolia)
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(key);
        vm.startBroadcast(key);

        // 1. Base Facets
        DiamondCutFacet dCut = new DiamondCutFacet();
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownerF = new OwnershipFacet();

        // 2. Prepare Base Cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);
        cuts[0] = cut(address(dCut), getSelectorsForDiamondCut());
        cuts[1] = cut(address(dLoupe), getSelectorsForDiamondLoupe());
        cuts[2] = cut(address(ownerF), getSelectorsForOwnership());

        // 3. Deploy Diamond
        Diamond diamond = new Diamond(deployer, cuts);
        console.log("Diamond:", address(diamond));

        // 4. Utility Facets
        YieldAggregatorFacet yieldFacet = new YieldAggregatorFacet();
        GelatoAutomationFacet gelatoFacet = new GelatoAutomationFacet();
        AaveV3Facet aaveFacet = new AaveV3Facet();

        IDiamondCut.FacetCut[] memory utilityCuts = new IDiamondCut.FacetCut[](3);
        utilityCuts[0] = cut(address(yieldFacet), getSelectorsForYieldAggregator());
        utilityCuts[1] = cut(address(gelatoFacet), getSelectorsForGelato());
        utilityCuts[2] = cut(address(aaveFacet), getSelectorsForAave());

        DiamondCutFacet(address(diamond)).diamondCut(utilityCuts, address(0), "");

        // 5. Deploy & Register Strategy
        AaveStrategy aaveStrategy = new AaveStrategy(AAVE_POOL);
        YieldAggregatorFacet(address(diamond)).addStrategy(USDC, address(aaveStrategy));
        YieldAggregatorFacet(address(diamond)).setRebalanceThreshold(50); // 0.5%

        vm.stopBroadcast();
    }

    function cut(address _facet, bytes4[] memory _sigs) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: _facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _sigs
        });
    }

    // Selector helper functions
    function getSelectorsForDiamondCut() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("diamondCut(((address,uint8,bytes4[]))[],address,bytes)"));
        return selectors;
    }

    function getSelectorsForDiamondLoupe() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = bytes4(keccak256("facets()"));
        selectors[1] = bytes4(keccak256("facetFunctionSelectors(address)"));
        selectors[2] = bytes4(keccak256("facetAddresses()"));
        selectors[3] = bytes4(keccak256("facetAddress(bytes4)"));
        return selectors;
    }

    function getSelectorsForOwnership() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("transferOwnership(address)"));
        selectors[1] = bytes4(keccak256("owner()"));
        return selectors;
    }

    function getSelectorsForYieldAggregator() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = bytes4(keccak256("deposit(address,uint256)"));
        selectors[1] = bytes4(keccak256("withdraw(address,uint256)"));
        selectors[2] = bytes4(keccak256("addStrategy(address,address)"));
        selectors[3] = bytes4(keccak256("getBestStrategy(address)"));
        selectors[4] = bytes4(keccak256("setRebalanceThreshold(uint256)"));
        return selectors;
    }

    function getSelectorsForGelato() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("checker(address)"));
        selectors[1] = bytes4(keccak256("configureGelatoAutomation(address,address)"));
        return selectors;
    }

    function getSelectorsForAave() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("lend(address,uint256)"));
        selectors[1] = bytes4(keccak256("withdraw(address,uint256)"));
        return selectors;
    }
}