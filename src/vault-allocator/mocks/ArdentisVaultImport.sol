// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
// Force foundry to compile ArdentisVault even though it's not imported by the public allocator or by the tests.
// ArdentisVault will be compiled with its own solidity version.
// The resulting bytecode is then loaded by the tests.

import "ardentis-vault/ArdentisVault.sol";
