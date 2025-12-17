pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { Ardentis } from "ardentis/Ardentis.sol";
import { MarketParams, Id } from "ardentis/interfaces/IArdentis.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";

contract MarketBorrow is Script {
  using MarketParamsLib for MarketParams;

  Ardentis ardentis = Ardentis(0x467E1Fb925057Bc7ce729333E02eA87AeCCa6208);

  address loanToken = 0x26eE8a41b8fC658f23C7B2f379EB0b86B3E9798F;
  address collateralToken = 0xb8f2018624142F236c4D91480b9cC0100E88C2D3;
  address oracle = 0x522489504f3455c4D87C21D2119edfa1BEC76882;
  address irm = 0x5ccaE2Ed56c8B5D00F9F1a10fD214Bf4f316df36;
  uint256 lltv = 800000000000000000;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    MarketParams memory param = MarketParams({
      loanToken: loanToken,
      collateralToken: collateralToken,
      oracle: oracle,
      irm: irm,
      lltv: lltv
    });
    uint256 assets = 5000 * 1e18;
    address user = deployer;

    vm.startBroadcast(deployerPrivateKey);

    ardentis.borrow(param, assets, 0, user, user);

    vm.stopBroadcast();
  }
}
