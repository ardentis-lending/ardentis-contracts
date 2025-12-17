// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ResilientOracle } from "../src/oracle/ResilientOracle.sol";
import { BoundValidator } from "../src/oracle/BoundValidator.sol";

// @notice Sample deployment script for forge-std/forge environment
// You can adapt this for your process/script runner.

contract ResilientOracleDeploy is Script {
  address boundValidatorAddr = 0xB2C7422eE56a6170ab50495a3EC4D4aa14833C7b;
  BoundValidator boundValidator = BoundValidator(boundValidatorAddr);

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Define multiple token configs
    BoundValidator.ValidateConfig[] memory configs = new BoundValidator.ValidateConfig[](3);

    configs[0] = BoundValidator.ValidateConfig({
      asset: 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F,
      upperBoundRatio: 1010000000000000000,
      lowerBoundRatio: 990000000000000000
    });
    configs[1] = BoundValidator.ValidateConfig({
      asset: 0x2f0022771009500940B086E75c18648C5d36e8AD,
      upperBoundRatio: 1010000000000000000,
      lowerBoundRatio: 990000000000000000
    });
    configs[2] = BoundValidator.ValidateConfig({
      asset: 0xb8f2018624142F236c4D91480b9cC0100E88C2D3,
      upperBoundRatio: 1010000000000000000,
      lowerBoundRatio: 990000000000000000
    });

    boundValidator.setValidateConfigs(configs);

    vm.stopBroadcast();
  }
}
