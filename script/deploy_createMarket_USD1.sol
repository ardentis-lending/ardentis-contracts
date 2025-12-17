pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { Ardentis } from "ardentis/Ardentis.sol";
import { MarketParams, Id } from "ardentis/interfaces/IArdentis.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";

contract CreateMarketDeploy is Script {
  using MarketParamsLib for MarketParams;

  // todo update ardentis irm liquidator oracleAdapter
  Ardentis ardentis = Ardentis(0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C);
  address USD1 = 0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d;
  address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
  address BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;

  address multiOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;

  address irm = 0xFe7dAe87Ebb11a7BEB9F534BB23267992d9cDe7c;

  uint256 lltv70 = 70 * 1e16;

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    MarketParams[] memory params = new MarketParams[](2);
    // collateral-BTCB loan-USD1 lltv-70%
    params[0] = MarketParams({ loanToken: USD1, collateralToken: BTCB, oracle: multiOracle, irm: irm, lltv: lltv70 });
    // collateral-WBNB loan-USD1 lltv-70%
    params[1] = MarketParams({ loanToken: USD1, collateralToken: WBNB, oracle: multiOracle, irm: irm, lltv: lltv70 });

    vm.startBroadcast(deployerPrivateKey);

    for (uint256 i = 0; i < 2; i++) {
      // create market
      ardentis.createMarket(params[i]);
    }

    vm.stopBroadcast();
  }
}
