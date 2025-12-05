// ============================================
// FILE: src/interfaces/IAToken.sol (for Aave)
// ============================================
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAToken as IAaveAToken} from "@aave/aave-v3-core/contracts/interfaces/IAToken.sol";

// Just re-export it
interface IAToken is IAaveAToken {}