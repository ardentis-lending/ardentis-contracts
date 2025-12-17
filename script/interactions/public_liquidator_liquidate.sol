// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import { IPublicLiquidator } from "../../src/liquidator/IPublicLiquidator.sol";

/// @title PublicLiquidatorLiquidate
/// @notice Script to liquidate a borrower position using PublicLiquidator.
contract PublicLiquidatorLiquidate is Script {
  IPublicLiquidator publicLiquidator = IPublicLiquidator(0x80d860533F70acF983d806b0249b27a08DD52F63);

  bytes32 marketId = 0x0a06f90a1a84689b7bc071be5b2c00111ce858add1845b4c4c8246f1df1d1db2;
  address borrower = 0x115274Fd5df5C55844eD711c06a2ed9571723411;
  uint256 seizedAssets = 9747353522043118415;
  uint256 repaidShares = 0;

  /// @notice Executes the script to liquidate a borrower position.
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    vm.startBroadcast(deployerPrivateKey);

    // Call liquidate function on PublicLiquidator
    publicLiquidator.liquidate(marketId, borrower, seizedAssets, repaidShares);

    vm.stopBroadcast();
  }
}
