// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
// Force foundry to compile Ardentis even though it's not imported by ArdentisVault or by the tests.
// Ardentis will be compiled with its own solidity version.
// The resulting bytecode is then loaded by BaseTest.sol.

import "ardentis/Ardentis.sol";
