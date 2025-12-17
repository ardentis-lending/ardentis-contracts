pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ArdentisVault } from "ardentis-vault/ArdentisVault.sol";

contract ArdentisVaultDeploy is Script {
  address ardentis = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;

  address USD1 = 0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d;
  address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
  address USDT = 0x55d398326f99059fF775485246999027B3197955;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy ArdentisVault implementation
    ArdentisVault implWBnb = new ArdentisVault(ardentis, WBNB);
    console.log("ArdentisVault(WBNB) implementation: ", address(implWBnb));

    vm.stopBroadcast();
  }
}
