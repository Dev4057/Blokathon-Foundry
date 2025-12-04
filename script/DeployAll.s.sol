// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

// 1. Interfaces & Core
import {IDiamondCut} from "src/facets/baseFacets/cut/IDiamondCut.sol";
import {IDiamondLoupe} from "src/facets/baseFacets/loupe/IDiamondLoupe.sol";
import {IERC173} from "src/interfaces/IERC173.sol";
import {IERC165} from "src/interfaces/IERC165.sol";

// 2. Base Contracts
import {Diamond} from "src/Diamond.sol";
import {DiamondCutFacet} from "src/facets/baseFacets/cut/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/facets/baseFacets/loupe/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/facets/baseFacets/ownership/OwnershipFacet.sol";

// 3. Logic Contracts (The Business Logic)
import {YieldAggregatorFacet} from "src/facets/utilityFacets/yieldAggregator/YieldAggregatorFacet.sol";
import {GelatoAutomationFacet} from "src/facets/utilityFacets/yieldAggregator/GelatoAutomationFacet.sol";
import {AaveV3Facet} from "src/facets/utilityFacets/aaveV3/AaveV3Facet.sol";

// 4. Strategies
import {AaveStrategy} from "src/facets/utilityFacets/yieldAggregator/strategies/AaveStrategy.sol";

contract DeployAll is Script {
    // Configuration (SEPOLIA EXAMPLES - CHANGE FOR MAINNET)
    address constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Sepolia Aave Pool
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;      // Sepolia USDC
    address constant GELATO_OPS = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F; // Gelato Ops
    
    // State variables to hold deployed addresses
    Diamond diamond;
    DiamondCutFacet dCut;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    YieldAggregatorFacet yieldF;
    GelatoAutomationFacet gelatoF;
    AaveV3Facet aaveF;
    AaveStrategy aaveStrategy;

    function run() public {
        // 1. Setup
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ANVIL");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // =========================================================
        // PHASE 1: Deploy Base System (The Container)
        // =========================================================
        
        // 1. Deploy Base Facets
        dCut = new DiamondCutFacet();
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        
        // 2. Prepare Base Cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(dCut),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsCut()
        });
        
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(dLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsLoupe()
        });
        
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownerF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsOwnership()
        });

        // 3. Deploy Diamond
        diamond = new Diamond(deployer, cuts);
        console.log("--------------------------------------------------");
        console.log("DIAMOND DEPLOYED AT:", address(diamond));
        console.log("--------------------------------------------------");

        // =========================================================
        // PHASE 2: Deploy Business Logic (The Features)
        // =========================================================
        
        yieldF = new YieldAggregatorFacet();
        gelatoF = new GelatoAutomationFacet();
        aaveF = new AaveV3Facet();
        
        // =========================================================
        // PHASE 3: Cut Logic into Diamond
        // =========================================================
        
        IDiamondCut.FacetCut[] memory logicCuts = new IDiamondCut.FacetCut[](3);
        
        logicCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(yieldF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsYield()
        });
        
        logicCuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(gelatoF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsGelato()
        });
        
        logicCuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(aaveF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsAave()
        });

        DiamondCutFacet(address(diamond)).diamondCut(logicCuts, address(0), "");
        console.log("Business Logic Added");

        // =========================================================
        // PHASE 4: Initialization & Strategy Setup
        // =========================================================

        // 1. Deploy Strategy
        aaveStrategy = new AaveStrategy(AAVE_POOL);
        console.log("AaveStrategy Deployed:", address(aaveStrategy));

        // 2. Whitelist Strategy in Diamond
        // Note: We cast the Diamond address to the Facet interface to call the function
        YieldAggregatorFacet(address(diamond)).addStrategy(USDC, address(aaveStrategy));
        YieldAggregatorFacet(address(diamond)).setRebalanceThreshold(50); // 0.5%
        
        console.log("Strategy Whitelisted in Diamond");

        // 3. Configure Automation
        GelatoAutomationFacet(address(diamond)).configureGelatoAutomation(
            1 hours, // Cooldown
            true,    // Enabled
            GELATO_OPS
        );
        console.log("Automation Configured");

        vm.stopBroadcast();
    }

    // =========================================================
    // SELECTOR HELPERS (Type-Safe & Explicit)
    // =========================================================

    function getSelectorsCut() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = IDiamondCut.diamondCut.selector;
    }

    function getSelectorsLoupe() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](5);
        s[0] = IDiamondLoupe.facets.selector;
        s[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        s[2] = IDiamondLoupe.facetAddresses.selector;
        s[3] = IDiamondLoupe.facetAddress.selector;
        s[4] = IERC165.supportsInterface.selector;
    }

    function getSelectorsOwnership() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = IERC173.owner.selector;
        s[1] = IERC173.transferOwnership.selector;
    }

    function getSelectorsYield() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](9); 
        s[0] = YieldAggregatorFacet.deposit.selector;
        s[1] = YieldAggregatorFacet.withdraw.selector;
        s[2] = YieldAggregatorFacet.rebalance.selector;
        s[3] = YieldAggregatorFacet.addStrategy.selector;
        s[4] = YieldAggregatorFacet.removeStrategy.selector;
        s[5] = YieldAggregatorFacet.setRebalanceThreshold.selector;
        s[6] = YieldAggregatorFacet.getUserBalance.selector;
        s[7] = YieldAggregatorFacet.getBestStrategy.selector;
        s[8] = YieldAggregatorFacet.getCurrentAPY.selector;
    }

    function getSelectorsGelato() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](4);
        s[0] = GelatoAutomationFacet.checker.selector;
        s[1] = GelatoAutomationFacet.executeRebalance.selector;
        s[2] = GelatoAutomationFacet.configureGelatoAutomation.selector;
        s[3] = GelatoAutomationFacet.pauseGelatoAutomation.selector;
    }

    function getSelectorsAave() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](3);
        s[0] = AaveV3Facet.getReserveData.selector;
        s[1] = AaveV3Facet.lend.selector;
        s[2] = AaveV3Facet.withdraw.selector;
    }
}