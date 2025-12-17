// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BaseTest.sol";

contract CreateMarketIntegrationTest is BaseTest {
  using MathLib for uint256;
  using MarketParamsLib for MarketParams;

  function testCreateMarketWithNotEnabledIrmAndNotEnabledLltv(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }
    vm.assume(!ardentis.isIrmEnabled(marketParamsFuzz.irm) && !ardentis.isLltvEnabled(marketParamsFuzz.lltv));

    vm.expectRevert(bytes(ErrorsLib.IRM_NOT_ENABLED));
    vm.prank(OWNER);
    ardentis.createMarket(marketParamsFuzz);
  }

  function testCreateMarketWithNotEnabledIrmAndEnabledLltv(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }
    vm.assume(!ardentis.isIrmEnabled(marketParamsFuzz.irm));

    vm.expectRevert(bytes(ErrorsLib.IRM_NOT_ENABLED));
    vm.prank(OWNER);
    ardentis.createMarket(marketParamsFuzz);
  }

  function testCreateMarketWithEnabledIrmAndNotEnabledLltv(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }
    vm.assume(!ardentis.isLltvEnabled(marketParamsFuzz.lltv));

    vm.startPrank(OWNER);
    if (!ardentis.isIrmEnabled(marketParamsFuzz.irm)) ardentis.enableIrm(marketParamsFuzz.irm);
    vm.stopPrank();

    vm.expectRevert(bytes(ErrorsLib.LLTV_NOT_ENABLED));
    vm.prank(OWNER);
    ardentis.createMarket(marketParamsFuzz);
  }

  function testCreateMarketWithEnabledIrmAndLltv(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }
    marketParamsFuzz.irm = address(irm);
    marketParamsFuzz.lltv = _boundValidLltv(marketParamsFuzz.lltv);
    marketParamsFuzz.oracle = address(oracle);
    Id marketParamsFuzzId = marketParamsFuzz.id();

    vm.startPrank(OWNER);
    if (!ardentis.isLltvEnabled(marketParamsFuzz.lltv)) ardentis.enableLltv(marketParamsFuzz.lltv);
    vm.stopPrank();

    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.CreateMarket(marketParamsFuzz.id(), marketParamsFuzz);
    vm.prank(OWNER);
    ardentis.createMarket(marketParamsFuzz);

    assertEq(ardentis.market(marketParamsFuzzId).lastUpdate, block.timestamp, "lastUpdate != block.timestamp");
    assertEq(ardentis.market(marketParamsFuzzId).totalSupplyAssets, 0, "totalSupplyAssets != 0");
    assertEq(ardentis.market(marketParamsFuzzId).totalSupplyShares, 0, "totalSupplyShares != 0");
    assertEq(ardentis.market(marketParamsFuzzId).totalBorrowAssets, 0, "totalBorrowAssets != 0");
    assertEq(ardentis.market(marketParamsFuzzId).totalBorrowShares, 0, "totalBorrowShares != 0");
    assertNotEq(ardentis.market(marketParamsFuzzId).fee, 0, "fee != 0");
  }

  function testCreateMarketAlreadyCreated(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }
    marketParamsFuzz.oracle = address(oracle);
    marketParamsFuzz.irm = address(irm);
    marketParamsFuzz.lltv = _boundValidLltv(marketParamsFuzz.lltv);

    vm.startPrank(OWNER);
    if (!ardentis.isLltvEnabled(marketParamsFuzz.lltv)) ardentis.enableLltv(marketParamsFuzz.lltv);
    vm.stopPrank();

    vm.prank(OWNER);
    ardentis.createMarket(marketParamsFuzz);

    vm.expectRevert(bytes(ErrorsLib.MARKET_ALREADY_CREATED));
    vm.prank(OWNER);
    ardentis.createMarket(marketParamsFuzz);
  }

  function testIdToMarketParams(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }
    marketParamsFuzz.irm = address(irm);
    marketParamsFuzz.lltv = _boundValidLltv(marketParamsFuzz.lltv);
    marketParamsFuzz.oracle = address(oracle);
    Id marketParamsFuzzId = marketParamsFuzz.id();

    vm.startPrank(OWNER);
    if (!ardentis.isLltvEnabled(marketParamsFuzz.lltv)) ardentis.enableLltv(marketParamsFuzz.lltv);
    vm.stopPrank();

    vm.prank(OWNER);
    ardentis.createMarket(marketParamsFuzz);

    MarketParams memory params = ardentis.idToMarketParams(marketParamsFuzzId);

    assertEq(marketParamsFuzz.loanToken, params.loanToken, "loanToken != loanToken");
    assertEq(marketParamsFuzz.collateralToken, params.collateralToken, "collateralToken != collateralToken");
    assertEq(marketParamsFuzz.irm, params.irm, "irm != irm");
    assertEq(marketParamsFuzz.lltv, params.lltv, "lltv != lltv");
  }

  function testCreateMarketWithOperator(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }

    marketParamsFuzz.irm = address(irm);
    marketParamsFuzz.lltv = _boundValidLltv(marketParamsFuzz.lltv);
    marketParamsFuzz.oracle = address(oracle);
    Id marketParamsFuzzId = marketParamsFuzz.id();

    vm.startPrank(OWNER);
    if (!ardentis.isLltvEnabled(marketParamsFuzz.lltv)) ardentis.enableLltv(marketParamsFuzz.lltv);
    vm.stopPrank();

    vm.startPrank(OWNER);
    ardentis.grantRole(OPERATOR_ROLE, OPERATOR);
    vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED));
    ardentis.createMarket(marketParamsFuzz);
    vm.stopPrank();

    vm.startPrank(OPERATOR);
    ardentis.createMarket(marketParamsFuzz);
    vm.stopPrank();

    MarketParams memory params = ardentis.idToMarketParams(marketParamsFuzzId);

    assertEq(marketParamsFuzz.loanToken, params.loanToken, "loanToken != loanToken");
    assertEq(marketParamsFuzz.collateralToken, params.collateralToken, "collateralToken != collateralToken");
    assertEq(marketParamsFuzz.irm, params.irm, "irm != irm");
    assertEq(marketParamsFuzz.lltv, params.lltv, "lltv != lltv");
  }

  function testCreateMarketNotOperator(MarketParams memory marketParamsFuzz) public {
    if (marketParamsFuzz.loanToken == address(0) || marketParamsFuzz.collateralToken == address(0)) {
      return;
    }

    marketParamsFuzz.irm = address(irm);
    marketParamsFuzz.lltv = _boundValidLltv(marketParamsFuzz.lltv);
    marketParamsFuzz.oracle = address(oracle);
    Id marketParamsFuzzId = marketParamsFuzz.id();

    vm.startPrank(OWNER);
    if (!ardentis.isLltvEnabled(marketParamsFuzz.lltv)) ardentis.enableLltv(marketParamsFuzz.lltv);
    vm.stopPrank();

    ardentis.createMarket(marketParamsFuzz);

    MarketParams memory params = ardentis.idToMarketParams(marketParamsFuzzId);

    assertEq(marketParamsFuzz.loanToken, params.loanToken, "loanToken != loanToken");
    assertEq(marketParamsFuzz.collateralToken, params.collateralToken, "collateralToken != collateralToken");
    assertEq(marketParamsFuzz.irm, params.irm, "irm != irm");
    assertEq(marketParamsFuzz.lltv, params.lltv, "lltv != lltv");
  }
}
