// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import { IArdentis, MarketParams, Market, Id } from "ardentis/interfaces/IArdentis.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";
import { MathLib } from "ardentis/libraries/MathLib.sol";
import { UtilsLib } from "ardentis/libraries/UtilsLib.sol";
import { ORACLE_PRICE_SCALE } from "ardentis/libraries/ConstantsLib.sol";
import { SharesMathLib } from "ardentis/libraries/SharesMathLib.sol";
import { IIrm } from "ardentis/interfaces/IIrm.sol";

/// @title MarketMaxBorrow
/// @notice Script to borrow the maximum amount available based on collateral and current borrow position.
contract MarketMaxBorrow is Script {
  using MarketParamsLib for MarketParams;
  using MathLib for uint128;
  using MathLib for uint256;
  using UtilsLib for uint256;
  using SharesMathLib for uint256;

  IArdentis public constant ARDENTIS = IArdentis(0x467E1Fb925057Bc7ce729333E02eA87AeCCa6208);

  address public constant LOAN_TOKEN = 0x824957847cB044F4B9607dcECA49Be74E6f7F15f;
  address public constant COLLATERAL_TOKEN = 0xb8f2018624142F236c4D91480b9cC0100E88C2D3;
  address public constant ORACLE = 0x522489504f3455c4D87C21D2119edfa1BEC76882;
  address public constant IRM = 0x5ccaE2Ed56c8B5D00F9F1a10fD214Bf4f316df36;
  uint256 public constant LLTV = 750000000000000000; // 75%
  uint256 public constant INTEREST_ACCURAL_GAP_SECONDS = 60; // Forward-looking time gap for interest calculation

  /// @notice Executes the script to borrow maximum available amount.
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);
    console.log("Deployer: ", deployer);

    MarketParams memory marketParams = MarketParams({
      loanToken: LOAN_TOKEN,
      collateralToken: COLLATERAL_TOKEN,
      oracle: ORACLE,
      irm: IRM,
      lltv: LLTV
    });
    address borrower = deployer;

    vm.startBroadcast(deployerPrivateKey);

    Id marketId = marketParams.id();

    // Calculate current borrowed assets (expected after interest accrual with forward-looking gap)
    uint256 currentBorrowedAssets = expectedBorrowAssets(
      ARDENTIS,
      marketParams,
      borrower,
      INTEREST_ACCURAL_GAP_SECONDS
    );

    // Get collateral amount and current price
    uint256 collateralAmount = uint256(ARDENTIS.position(marketId, borrower).collateral);
    uint256 collateralPrice = ARDENTIS.getPrice(marketParams);

    // Calculate maximum borrowable amount based on collateral value and LLTV
    uint256 maxBorrowableAssets = collateralAmount.mulDivDown(collateralPrice, ORACLE_PRICE_SCALE).wMulDown(
      marketParams.lltv
    );

    // Validate that current borrowed assets don't exceed maximum borrowable amount
    if (currentBorrowedAssets >= maxBorrowableAssets) {
      console.log("Current borrowed assets: ", currentBorrowedAssets);
      console.log("Maximum borrowable assets: ", maxBorrowableAssets);
      console.log("Cannot borrow: current debt already at or exceeds maximum borrowable amount");
      vm.stopBroadcast();
      return;
    }

    // Calculate remaining borrowable amount
    uint256 remainingBorrowableAssets = maxBorrowableAssets - currentBorrowedAssets;

    console.log("Current borrowed assets: ", currentBorrowedAssets);
    console.log("Maximum borrowable assets: ", maxBorrowableAssets);
    console.log("Remaining borrowable assets: ", remainingBorrowableAssets);

    // Borrow the remaining available amount
    ARDENTIS.borrow(marketParams, remainingBorrowableAssets, 0, borrower, borrower);

    vm.stopBroadcast();
  }

  /// @notice Returns the expected market balances after interest accrual.
  /// @param gapInSeconds Additional seconds to add to the current timestamp for forward-looking calculations.
  /// @return totalSupplyAssets Expected total supply assets after interest accrual.
  /// @return totalSupplyShares Expected total supply shares after interest accrual.
  /// @return totalBorrowAssets Expected total borrow assets after interest accrual.
  /// @return totalBorrowShares Total borrow shares (unchanged by interest accrual).
  function expectedMarketBalances(
    IArdentis ardentis,
    MarketParams memory marketParams,
    uint256 gapInSeconds
  ) internal view returns (uint256, uint256, uint256, uint256) {
    Id id = marketParams.id();
    Market memory market = ardentis.market(id);

    uint256 elapsed = block.timestamp + gapInSeconds - market.lastUpdate;

    // Skip interest accrual if elapsed == 0, totalBorrowAssets == 0, or irm == address(0)
    if (elapsed != 0 && market.totalBorrowAssets != 0 && marketParams.irm != address(0)) {
      uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
      uint256 interest = market.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
      market.totalBorrowAssets += interest.toUint128();
      market.totalSupplyAssets += interest.toUint128();

      if (market.fee != 0) {
        uint256 feeAmount = interest.wMulDown(market.fee);
        // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
        // that total supply is already updated.
        uint256 feeShares = feeAmount.toSharesDown(market.totalSupplyAssets - feeAmount, market.totalSupplyShares);
        market.totalSupplyShares += feeShares.toUint128();
      }
    }

    return (market.totalSupplyAssets, market.totalSupplyShares, market.totalBorrowAssets, market.totalBorrowShares);
  }

  /// @notice Returns the expected borrow assets balance of `user` after interest accrual.
  /// @param gapInSeconds Additional seconds to add to the current timestamp for forward-looking calculations.
  /// @dev Warning: The expected balance is rounded up, so it may be greater than the market's expected total borrow assets.
  /// @return Expected borrow assets balance after interest accrual.
  function expectedBorrowAssets(
    IArdentis ardentis,
    MarketParams memory marketParams,
    address user,
    uint256 gapInSeconds
  ) internal view returns (uint256) {
    Id id = marketParams.id();
    uint256 borrowShares = uint256(ardentis.position(id, user).borrowShares);
    (, , uint256 totalBorrowAssets, uint256 totalBorrowShares) = expectedMarketBalances(
      ardentis,
      marketParams,
      gapInSeconds
    );

    return borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);
  }
}
