pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ArdentisVaultFactoryInternal } from "ardentis-vault/ArdentisVaultFactoryInternal.sol";

contract ArdentisVaultFactoryInternalDeploy is Script {
  address ardentis = 0x467E1Fb925057Bc7ce729333E02eA87AeCCa6208;
  address vaultAdmin = 0xe053eF3F8169f836f731B28A8Bd5500189b16591;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);
    vm.startBroadcast(deployerPrivateKey);

    // Deploy ArdentisVaultFactoryInternal implementation
    ArdentisVaultFactoryInternal impl = new ArdentisVaultFactoryInternal(ardentis);
    console.log("ArdentisVaultFactoryInternal implementation: ", address(impl));

    // Deploy ArdentisVaultFactoryInternal proxy
    ERC1967Proxy proxy = new ERC1967Proxy(
      address(impl),
      abi.encodeWithSelector(impl.initialize.selector, deployer, vaultAdmin)
    );
    console.log("ArdentisVaultFactoryInternal proxy: ", address(proxy));

    vm.stopBroadcast();
  }
}
