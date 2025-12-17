// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ResilientOracle } from "../src/oracle/ResilientOracle.sol";
import { ResilientOracle } from "../src/oracle/ResilientOracle.sol";

// @notice Sample deployment script for forge-std/forge environment
// You can adapt this for your process/script runner.

contract ResilientOracleDeploy is Script {
  address resilientOracleAddr = 0x522489504f3455c4D87C21D2119edfa1BEC76882;
  ResilientOracle resilientOracle = ResilientOracle(resilientOracleAddr);

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Define multiple token configs
    ResilientOracle.TokenConfig[] memory configs = new ResilientOracle.TokenConfig[](3);

    configs[0] = ResilientOracle.TokenConfig({
      asset: 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F,
      oracles: [
        0xEca2605f0BCF2BA5966372C99837b1F182d3D620,
        0xEca2605f0BCF2BA5966372C99837b1F182d3D620,
        0xEca2605f0BCF2BA5966372C99837b1F182d3D620
      ],
      enableFlagsForOracles: [true, true, true],
      timeDeltaTolerance: 86400
    });
    configs[1] = ResilientOracle.TokenConfig({
      asset: 0x2f0022771009500940B086E75c18648C5d36e8AD,
      oracles: [
        0x5741306c21795FdCBb9b265Ea0255F499DFe515C,
        0x5741306c21795FdCBb9b265Ea0255F499DFe515C,
        0x5741306c21795FdCBb9b265Ea0255F499DFe515C
      ],
      enableFlagsForOracles: [true, true, true],
      timeDeltaTolerance: 86400
    });
    configs[2] = ResilientOracle.TokenConfig({
      asset: 0xb8f2018624142F236c4D91480b9cC0100E88C2D3,
      oracles: [
        0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7,
        0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7,
        0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7
      ],
      enableFlagsForOracles: [true, true, true],
      timeDeltaTolerance: 86400
    });

    resilientOracle.setTokenConfigs(configs);

    vm.stopBroadcast();
  }
}
