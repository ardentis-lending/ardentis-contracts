// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BaseTest.sol";

contract SupplyIntegrationTest is BaseTest {
  using MathLib for uint256;
  using SharesMathLib for uint256;

  function testSupplyMarketNotCreated(MarketParams memory marketParamsFuzz, uint256 amount) public {
    vm.assume(neq(marketParamsFuzz, marketParams));

    vm.prank(SUPPLIER);
    vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
    ardentis.supply(marketParamsFuzz, amount, 0, SUPPLIER, hex"");
  }

  function testSupplyZeroAmount() public {
    vm.assume(SUPPLIER != address(0));

    vm.prank(SUPPLIER);
    vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_INPUT));
    ardentis.supply(marketParams, 0, 0, SUPPLIER, hex"");
  }

  function testSupplyOnBehalfZeroAddress(uint256 amount) public {
    amount = bound(amount, 1, MAX_TEST_AMOUNT);

    vm.prank(SUPPLIER);
    vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
    ardentis.supply(marketParams, amount, 0, address(0), hex"");
  }

  function testSupplyInconsistantInput(uint256 amount, uint256 shares) public {
    amount = bound(amount, 1, MAX_TEST_AMOUNT);
    shares = bound(shares, 1, MAX_TEST_SHARES);

    vm.prank(SUPPLIER);
    vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_INPUT));
    ardentis.supply(marketParams, amount, shares, address(0), hex"");
  }

  function testSupplyTokenNotCreated(uint256 amount, address token) public {
    amount = bound(amount, 1, MAX_TEST_AMOUNT);

    vm.assume(token.code.length == 0);

    marketParams.loanToken = token;
    marketParams.collateralToken = token;
    marketParams.oracle = address(oracle);

    vm.startPrank(OWNER);
    ardentis.createMarket(marketParams);
    vm.stopPrank();

    vm.expectRevert(bytes(ErrorsLib.NO_CODE));
    ardentis.supply(marketParams, amount, 0, ONBEHALF, hex"");
  }

  function testSupplyAssets(uint256 amount) public {
    amount = bound(amount, 1, MAX_TEST_AMOUNT);

    loanToken.setBalance(SUPPLIER, amount);

    uint256 expectedSupplyShares = amount.toSharesDown(0, 0);

    vm.prank(SUPPLIER);

    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.Supply(id, SUPPLIER, ONBEHALF, amount, expectedSupplyShares);
    (uint256 returnAssets, uint256 returnShares) = ardentis.supply(marketParams, amount, 0, ONBEHALF, hex"");

    assertEq(returnAssets, amount, "returned asset amount");
    assertEq(returnShares, expectedSupplyShares, "returned shares amount");
    assertEq(ardentis.position(id, ONBEHALF).supplyShares, expectedSupplyShares, "supply shares");
    assertEq(ardentis.market(id).totalSupplyAssets, amount, "total supply");
    assertEq(ardentis.market(id).totalSupplyShares, expectedSupplyShares, "total supply shares");
    assertEq(loanToken.balanceOf(SUPPLIER), 0, "SUPPLIER balance");
    assertEq(loanToken.balanceOf(address(ardentis)), amount, "ardentis balance");
  }

  function testSupplyShares(uint256 shares) public {
    shares = bound(shares, 1, MAX_TEST_SHARES);

    uint256 expectedSuppliedAmount = shares.toAssetsUp(0, 0);

    loanToken.setBalance(SUPPLIER, expectedSuppliedAmount);

    vm.prank(SUPPLIER);

    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.Supply(id, SUPPLIER, ONBEHALF, expectedSuppliedAmount, shares);
    (uint256 returnAssets, uint256 returnShares) = ardentis.supply(marketParams, 0, shares, ONBEHALF, hex"");

    assertEq(returnAssets, expectedSuppliedAmount, "returned asset amount");
    assertEq(returnShares, shares, "returned shares amount");
    assertEq(ardentis.position(id, ONBEHALF).supplyShares, shares, "supply shares");
    assertEq(ardentis.market(id).totalSupplyAssets, expectedSuppliedAmount, "total supply");
    assertEq(ardentis.market(id).totalSupplyShares, shares, "total supply shares");
    assertEq(loanToken.balanceOf(SUPPLIER), 0, "SUPPLIER balance");
    assertEq(loanToken.balanceOf(address(ardentis)), expectedSuppliedAmount, "ardentis balance");
  }
}
