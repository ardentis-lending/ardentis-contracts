// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ArdentisVault } from "ardentis-vault/ArdentisVault.sol";
import { MarketAllocation } from "ardentis-vault/interfaces/IArdentisVault.sol";
import { MarketParams } from "ardentis/interfaces/IArdentis.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";

contract VaultReallocate is Script {
  using MarketParamsLib for MarketParams;

  ArdentisVault vault = ArdentisVault(0xc399e19e57e6752EF266D0054afbD24e0665c00F);

  // Struct to group all market parameters together
  struct MarketConfig {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
    uint256 assets; // 0 = withdraw all, specific amount = supply that amount
  }

  // Define markets - each market is grouped together with all its parameters
  MarketConfig[] markets = [
    MarketConfig({
      loanToken: 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F,
      collateralToken: 0x824957847cB044F4B9607dcECA49Be74E6f7F15f,
      oracle: 0x522489504f3455c4D87C21D2119edfa1BEC76882,
      irm: 0x5ccaE2Ed56c8B5D00F9F1a10fD214Bf4f316df36,
      lltv: 915000000000000000,
      assets: 2_000_000 * 1e18
    }),
    MarketConfig({
      loanToken: 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F,
      collateralToken: 0x732ad18653034f2Eb44Dc54362Fe1A375a274E20,
      oracle: 0x522489504f3455c4D87C21D2119edfa1BEC76882,
      irm: 0x5ccaE2Ed56c8B5D00F9F1a10fD214Bf4f316df36,
      lltv: 750000000000000000,
      assets: 2_000_000 * 1e18 // supply this amount
    }),
    MarketConfig({
      loanToken: 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F,
      collateralToken: 0xb8f2018624142F236c4D91480b9cC0100E88C2D3,
      oracle: 0x522489504f3455c4D87C21D2119edfa1BEC76882,
      irm: 0x5ccaE2Ed56c8B5D00F9F1a10fD214Bf4f316df36,
      lltv: 800000000000000000,
      assets: 3_000_000 * 1e18 // supply this amount
    }),
    MarketConfig({
      loanToken: 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F,
      collateralToken: 0x2f0022771009500940B086E75c18648C5d36e8AD,
      oracle: 0x522489504f3455c4D87C21D2119edfa1BEC76882,
      irm: 0x5ccaE2Ed56c8B5D00F9F1a10fD214Bf4f316df36,
      lltv: 800000000000000000,
      assets: 500_000 * 1e18 // supply this amount
    })
  ];

  // Idle market params for final allocation
  MarketParams idleParams =
    MarketParams({
      loanToken: 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F,
      collateralToken: 0x824957847cB044F4B9607dcECA49Be74E6f7F15f,
      oracle: 0x522489504f3455c4D87C21D2119edfa1BEC76882,
      irm: 0x5ccaE2Ed56c8B5D00F9F1a10fD214Bf4f316df36,
      lltv: 915000000000000000
    });

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    uint256 numMarkets = markets.length;

    // Create allocations array: one for each market + one final allocation
    MarketAllocation[] memory allocations = new MarketAllocation[](numMarkets + 1);

    // Build allocations for each market
    for (uint256 i = 0; i < numMarkets; i++) {
      MarketConfig memory config = markets[i];

      MarketParams memory marketParams = MarketParams({
        loanToken: config.loanToken,
        collateralToken: config.collateralToken,
        oracle: config.oracle,
        irm: config.irm,
        lltv: config.lltv
      });

      allocations[i] = MarketAllocation({ marketParams: marketParams, assets: config.assets });
    }

    // Final allocation: Supply remaining withdrawn liquidity (use type(uint256).max)
    allocations[numMarkets] = MarketAllocation({
      marketParams: idleParams,
      assets: type(uint256).max // Supply all remaining withdrawn liquidity
    });

    vm.startBroadcast(deployerPrivateKey);

    vault.reallocate(allocations);

    vm.stopBroadcast();
  }
}
