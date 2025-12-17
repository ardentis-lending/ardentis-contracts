pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { TimeLock } from "timelock/TimeLock.sol";
import { ArdentisVault } from "ardentis-vault/ArdentisVault.sol";

contract TimeLockExecute is Script {
  TimeLock lock = TimeLock(payable(0xe401939719A34c79B1387F1cD0aDb00c84c192A2));

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    vm.startBroadcast(deployerPrivateKey);

    // Correct way to encode the grantRole call data for the vault
    bytes memory payload = abi.encodeWithSignature("grantRole(bytes32,address)", keccak256("ALLOCATOR"), deployer);
    console.logBytes(payload);

    lock.execute(
      0xc399e19e57e6752EF266D0054afbD24e0665c00F,
      0,
      hex"2f2ff15ddcac51f5d253e2787a458cfb1d6b8faf248cf16367710f9e3b6bd5644d23f8db000000000000000000000000e053ef3f8169f836f731b28a8bd5500189b16591",
      bytes32(0),
      bytes32(0)
    );

    vm.stopBroadcast();
  }
}
