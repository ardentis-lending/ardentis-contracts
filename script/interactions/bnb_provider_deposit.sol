// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { BNBProvider } from "../../src/provider/BNBProvider.sol";

contract BNBProviderDeposit is Script {
  BNBProvider provider = BNBProvider(payable(0x236bCfD72b94B14F15aFCc9762bb8da3BF176620)); // Update with your BNBProvider address

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    // Amount of BNB to deposit (in wei)
    uint256 bnbAmount = 0.01 ether; // 1 BNB, adjust as needed
    address receiver = deployer;

    vm.startBroadcast(deployerPrivateKey);

    // Deposit BNB through BNBProvider
    // The provider will wrap BNB to WBNB and deposit into the vault
    provider.deposit{ value: bnbAmount }(receiver);

    vm.stopBroadcast();
  }
}
