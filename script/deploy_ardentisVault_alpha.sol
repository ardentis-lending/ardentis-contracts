pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ArdentisVault } from "ardentis-vault/ArdentisVault.sol";

contract ArdentisVaultDeploy is Script {
  address ardentis = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;

  address Take = 0xE747E54783Ba3F77a8E5251a3cBA19EBe9C0E197;

  ArdentisVault impl = ArdentisVault(0xA1f832c7C7ECf91A53b4ff36E0ABdb5133C15982);

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    address takeProxy = deployVault(deployer, Take, "Take Vault", "Take");

    console.log("Take Vault proxy: ", takeProxy);
    vm.stopBroadcast();
  }

  function deployVault(
    address deployer,
    address asset,
    string memory name,
    string memory symbol
  ) internal returns (address) {
    ERC1967Proxy proxy = new ERC1967Proxy(
      address(impl),
      abi.encodeWithSelector(impl.initialize.selector, deployer, deployer, asset, name, symbol)
    );
    return address(proxy);
  }
}
