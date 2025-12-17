pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ArdentisVault } from "ardentis-vault/ArdentisVault.sol";
import { ERC20Mock } from "ardentis-vault/mocks/ERC20Mock.sol";

contract VaultWithdraw is Script {
  ArdentisVault vault = ArdentisVault(0x3182087FeB38EB3D4cF1B9EF9cb1AB59863651c3);
  ERC20Mock vaultToken = ERC20Mock(0x3182087FeB38EB3D4cF1B9EF9cb1AB59863651c3);

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    address receiver = deployer;

    vm.startBroadcast(deployerPrivateKey);

    vault.redeem(vaultToken.balanceOf(receiver), receiver, receiver);

    vm.stopBroadcast();
  }
}
