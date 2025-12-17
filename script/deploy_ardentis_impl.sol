pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Ardentis } from "ardentis/Ardentis.sol";

contract ArdentisImplDeploy is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_TESTNET");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy Ardentis implementation
    Ardentis impl = new Ardentis();
    console.log("Ardentis implementation: ", address(impl));

    vm.stopBroadcast();
  }
}
