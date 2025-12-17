pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ArdentisVault } from "ardentis-vault/ArdentisVault.sol";
import { ERC20Mock } from "ardentis-vault/mocks/ERC20Mock.sol";

contract VaultDeposit is Script {
  ArdentisVault vault = ArdentisVault(0x3182087FeB38EB3D4cF1B9EF9cb1AB59863651c3);

  address loanTokenAddr = 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F;
  ERC20Mock loanToken = ERC20Mock(loanTokenAddr);

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    uint256 assets = 1000000 * 1e18;
    address receiver = deployer;

    vm.startBroadcast(deployerPrivateKey);

    loanToken.approve(address(vault), type(uint256).max);
    vault.deposit(assets, receiver);

    vm.stopBroadcast();
  }
}
