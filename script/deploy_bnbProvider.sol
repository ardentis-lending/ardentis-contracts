pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { BNBProvider } from "../src/provider/BNBProvider.sol";

contract BNBProviderDeploy is Script {
  address ardentis = 0x467E1Fb925057Bc7ce729333E02eA87AeCCa6208;
  address vault = 0xf843fe31031f8Fe7189678a2D61e54A8974D1F9C; // WBNB Vault
  address mevVault = 0xd5cfc0f894bA77e95E3325Aa53Eb3e6CBBb5A81E; // MEV WBNB Vault
  address loopVault = vault; // Loop WBNB Vault

  address asset = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // WBNB

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy BNBProvider implementation
    BNBProvider impl = new BNBProvider(ardentis, vault, asset);
    console.log("Loop WBNB Vault BNBProvider implementation: ", address(impl));

    // Deploy Loop WBNB Vault BNBProvider proxy
    ERC1967Proxy proxy = new ERC1967Proxy(
      address(impl),
      abi.encodeWithSelector(impl.initialize.selector, deployer, deployer)
    );
    console.log("Loop WBNB Vault BNBProvider proxy: ", address(proxy));

    vm.stopBroadcast();
  }
}
