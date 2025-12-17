// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ResilientOracle } from "../src/oracle/ResilientOracle.sol";
import { BoundValidator } from "../src/oracle/BoundValidator.sol";

// @notice Sample deployment script for forge-std/forge environment
// You can adapt this for your process/script runner.

contract ResilientOracleDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy BoundValidator implementation
    BoundValidator boundValidatorImpl = new BoundValidator();
    console.log("BoundValidator implementation: ", address(boundValidatorImpl));

    // Deploy BoundValidator proxy
    ERC1967Proxy boundValidatorProxy = new ERC1967Proxy(
      address(boundValidatorImpl),
      abi.encodeWithSelector(boundValidatorImpl.initialize.selector, deployer)
    );
    console.log("BoundValidator proxy: ", address(boundValidatorProxy));

    // Deploy ResilientOracle implementation
    ResilientOracle impl = new ResilientOracle();
    console.log("ResilientOracle implementation: ", address(impl));

    // Deploy ResilientOracle proxy
    ERC1967Proxy proxy = new ERC1967Proxy(
      address(impl),
      abi.encodeWithSelector(impl.initialize.selector, address(boundValidatorProxy), deployer)
    );
    console.log("ResilientOracle proxy: ", address(proxy));

    vm.stopBroadcast();
  }
}
