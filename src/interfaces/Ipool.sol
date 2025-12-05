// ============================================
// FILE: src/interfaces/IPool.sol (for Aave)
// ============================================
// This is just a re-export for convenience
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool as IAavePool} from "@aave/aave-v3-core/contracts/interfaces/IPool.sol";

// Just re-export it
interface IPool is IAavePool {}