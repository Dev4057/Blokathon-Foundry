// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*###############################################################################

    @title Facet Base Contract
    @author BLOK Capital DAO
    @notice Base contract that all facets inherit from
    @dev Provides common modifiers and utilities for facets

    ▗▄▄▖ ▗▖    ▗▄▖ ▗▖ ▗▖     ▗▄▄▖ ▗▄▖ ▗▄▄▖▗▄▄▄▖▗▄▄▄▖▗▄▖ ▗▖       ▗▄▄▄  ▗▄▖  ▗▄▖ 
    ▐▌ ▐▌▐▌   ▐▌ ▐▌▐▌▗▞▘    ▐▌   ▐▌ ▐▌▐▌ ▐▌ █    █ ▐▌ ▐▌▐▌       ▐▌  █▐▌ ▐▌▐▌ ▐▌
    ▐▛▀▚▖▐▌   ▐▌ ▐▌▐▛▚▖     ▐▌   ▐▛▀▜▌▐▛▀▘  █    █ ▐▛▀▜▌▐▌       ▐▌  █▐▛▀▜▌▐▌ ▐▌
    ▐▙▄▞▘▐▙▄▄▖▝▚▄▞▘▐▌ ▐▌    ▝▚▄▄▖▐▌ ▐▌▐▌  ▗▄█▄▖  █ ▐▌ ▐▌▐▙▄▄▖    ▐▙▄▄▀▐▌ ▐▌▝▚▄▞▘

################################################################################*/

import {OwnershipStorage} from "./baseFacets/ownership/OwnershipStorage.sol";

abstract contract Facet {
    
    /// @notice Modifier to restrict functions to contract owner only
    modifier onlyOwner() {
        require(
            msg.sender == OwnershipStorage.layout().owner,
            "Facet: caller is not the owner"
        );
        _;
    }

    /// @notice Modifier to restrict functions to diamond owner only (alias for onlyOwner)
    modifier onlyDiamondOwner() {
        require(
            msg.sender == OwnershipStorage.layout().owner,
            "Facet: caller is not the diamond owner"
        );
        _;
    }

    /// @notice Modifier to ensure non-zero address
    modifier notZeroAddress(address _address) {
        require(_address != address(0), "Facet: zero address");
        _;
    }

    /// @notice Modifier to ensure non-zero amount
    modifier notZeroAmount(uint256 _amount) {
        require(_amount > 0, "Facet: zero amount");
        _;
    }
}