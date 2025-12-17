// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BaseTest.sol";

contract BorrowIntegrationTest is BaseTest {
  using MathLib for uint256;
  using SharesMathLib for uint256;

  function testBorrowMarketNotCreated(
    MarketParams memory marketParamsFuzz,
    address borrowerFuzz,
    uint256 amount
  ) public {
    vm.assume(neq(marketParamsFuzz, marketParams));

    vm.prank(borrowerFuzz);
    vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
    ardentis.borrow(marketParamsFuzz, amount, 0, borrowerFuzz, RECEIVER);
  }

  function testBorrowZeroAmount(address borrowerFuzz) public {
    vm.prank(borrowerFuzz);
    vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_INPUT));
    ardentis.borrow(marketParams, 0, 0, borrowerFuzz, RECEIVER);
  }

  function testBorrowInconsistentInput(address borrowerFuzz, uint256 amount, uint256 shares) public {
    amount = bound(amount, 1, MAX_TEST_AMOUNT);
    shares = bound(shares, 1, MAX_TEST_SHARES);

    vm.prank(borrowerFuzz);
    vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_INPUT));
    ardentis.borrow(marketParams, amount, shares, borrowerFuzz, RECEIVER);
  }

  function testBorrowToZeroAddress(address borrowerFuzz, uint256 amount) public {
    amount = bound(amount, 1, MAX_TEST_AMOUNT);

    _supply(amount);

    vm.prank(borrowerFuzz);
    vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
    ardentis.borrow(marketParams, amount, 0, borrowerFuzz, address(0));
  }

  function testBorrowUnauthorized(address supplier, address attacker, uint256 amount) public {
    vm.assume(supplier != attacker && supplier != address(0));
    (uint256 amountCollateral, uint256 amountBorrowed, ) = _boundHealthyPosition(amount, amount, ORACLE_PRICE_SCALE);

    _supply(amountBorrowed);

    collateralToken.setBalance(supplier, amountCollateral);

    vm.startPrank(supplier);
    collateralToken.approve(address(ardentis), amountCollateral);
    ardentis.supplyCollateral(marketParams, amountCollateral, supplier, hex"");

    vm.startPrank(attacker);
    vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED));
    ardentis.borrow(marketParams, amountBorrowed, 0, supplier, RECEIVER);
  }

  function testBorrowUnhealthyPosition(
    uint256 amountCollateral,
    uint256 amountSupplied,
    uint256 amountBorrowed,
    uint256 priceCollateral
  ) public {
    (amountCollateral, amountBorrowed, priceCollateral) = _boundUnhealthyPosition(
      amountCollateral,
      amountBorrowed,
      priceCollateral
    );

    amountSupplied = bound(amountSupplied, amountBorrowed, MAX_TEST_AMOUNT);
    _supply(amountSupplied);

    oracle.setPrice(address(collateralToken), priceCollateral);

    collateralToken.setBalance(BORROWER, amountCollateral);

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, amountCollateral, BORROWER, hex"");
    vm.expectRevert(bytes(ErrorsLib.INSUFFICIENT_COLLATERAL));
    ardentis.borrow(marketParams, amountBorrowed, 0, BORROWER, BORROWER);
    vm.stopPrank();
  }

  function testBorrowUnsufficientLiquidity(
    uint256 amountCollateral,
    uint256 amountSupplied,
    uint256 amountBorrowed,
    uint256 priceCollateral
  ) public {
    (amountCollateral, amountBorrowed, priceCollateral) = _boundHealthyPosition(
      amountCollateral,
      amountBorrowed,
      priceCollateral
    );
    vm.assume(amountBorrowed >= 2);
    amountSupplied = bound(amountSupplied, 1, amountBorrowed - 1);
    _supply(amountSupplied);

    oracle.setPrice(address(collateralToken), priceCollateral);

    collateralToken.setBalance(BORROWER, amountCollateral);

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, amountCollateral, BORROWER, hex"");
    vm.expectRevert(bytes(ErrorsLib.INSUFFICIENT_LIQUIDITY));
    ardentis.borrow(marketParams, amountBorrowed, 0, BORROWER, BORROWER);
    vm.stopPrank();
  }

  function testBorrowAssets(
    uint256 amountCollateral,
    uint256 amountSupplied,
    uint256 amountBorrowed,
    uint256 priceCollateral
  ) public {
    (amountCollateral, amountBorrowed, priceCollateral) = _boundHealthyPosition(
      amountCollateral,
      amountBorrowed,
      priceCollateral
    );

    amountSupplied = bound(amountSupplied, amountBorrowed, MAX_TEST_AMOUNT);
    _supply(amountSupplied);

    oracle.setPrice(address(collateralToken), priceCollateral);

    collateralToken.setBalance(BORROWER, amountCollateral);

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, amountCollateral, BORROWER, hex"");

    uint256 expectedBorrowShares = amountBorrowed.toSharesUp(0, 0);

    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.Borrow(id, BORROWER, BORROWER, RECEIVER, amountBorrowed, expectedBorrowShares);
    (uint256 returnAssets, uint256 returnShares) = ardentis.borrow(marketParams, amountBorrowed, 0, BORROWER, RECEIVER);
    vm.stopPrank();

    assertEq(returnAssets, amountBorrowed, "returned asset amount");
    assertEq(returnShares, expectedBorrowShares, "returned shares amount");
    assertEq(ardentis.market(id).totalBorrowAssets, amountBorrowed, "total borrow");
    assertEq(ardentis.position(id, BORROWER).borrowShares, expectedBorrowShares, "borrow shares");
    assertEq(ardentis.position(id, BORROWER).borrowShares, expectedBorrowShares, "total borrow shares");
    assertEq(loanToken.balanceOf(RECEIVER), amountBorrowed, "borrower balance");
    assertEq(loanToken.balanceOf(address(ardentis)), amountSupplied - amountBorrowed, "ardentis balance");
  }

  function testBorrowShares(
    uint256 amountCollateral,
    uint256 amountSupplied,
    uint256 sharesBorrowed,
    uint256 priceCollateral
  ) public {
    priceCollateral = bound(priceCollateral, MIN_COLLATERAL_PRICE, MAX_COLLATERAL_PRICE);
    sharesBorrowed = bound(sharesBorrowed, MIN_TEST_SHARES, MAX_TEST_SHARES);
    uint256 expectedAmountBorrowed = sharesBorrowed.toAssetsDown(0, 0);
    uint256 expectedBorrowedValue = sharesBorrowed.toAssetsUp(expectedAmountBorrowed, sharesBorrowed);
    uint256 minCollateral = expectedBorrowedValue.wDivUp(marketParams.lltv).mulDivUp(
      ORACLE_PRICE_SCALE,
      priceCollateral
    );
    vm.assume(minCollateral <= MAX_COLLATERAL_ASSETS);
    amountCollateral = bound(amountCollateral, minCollateral, MAX_COLLATERAL_ASSETS);
    vm.assume(amountCollateral <= type(uint256).max / priceCollateral);

    amountSupplied = bound(amountSupplied, expectedAmountBorrowed, MAX_TEST_AMOUNT);
    _supply(amountSupplied);

    oracle.setPrice(address(collateralToken), priceCollateral);

    collateralToken.setBalance(BORROWER, amountCollateral);

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, amountCollateral, BORROWER, hex"");

    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.Borrow(id, BORROWER, BORROWER, RECEIVER, expectedAmountBorrowed, sharesBorrowed);
    (uint256 returnAssets, uint256 returnShares) = ardentis.borrow(marketParams, 0, sharesBorrowed, BORROWER, RECEIVER);
    vm.stopPrank();

    assertEq(returnAssets, expectedAmountBorrowed, "returned asset amount");
    assertEq(returnShares, sharesBorrowed, "returned shares amount");
    assertEq(ardentis.market(id).totalBorrowAssets, expectedAmountBorrowed, "total borrow");
    assertEq(ardentis.position(id, BORROWER).borrowShares, sharesBorrowed, "borrow shares");
    assertEq(ardentis.position(id, BORROWER).borrowShares, sharesBorrowed, "total borrow shares");
    assertEq(loanToken.balanceOf(RECEIVER), expectedAmountBorrowed, "borrower balance");
    assertEq(loanToken.balanceOf(address(ardentis)), amountSupplied - expectedAmountBorrowed, "ardentis balance");
  }

  function testBorrowAssetsOnBehalf(
    uint256 amountCollateral,
    uint256 amountSupplied,
    uint256 amountBorrowed,
    uint256 priceCollateral
  ) public {
    (amountCollateral, amountBorrowed, priceCollateral) = _boundHealthyPosition(
      amountCollateral,
      amountBorrowed,
      priceCollateral
    );

    amountSupplied = bound(amountSupplied, amountBorrowed, MAX_TEST_AMOUNT);
    _supply(amountSupplied);

    oracle.setPrice(address(collateralToken), priceCollateral);

    collateralToken.setBalance(ONBEHALF, amountCollateral);

    vm.startPrank(ONBEHALF);
    collateralToken.approve(address(ardentis), amountCollateral);
    ardentis.supplyCollateral(marketParams, amountCollateral, ONBEHALF, hex"");
    // BORROWER is already authorized.
    vm.stopPrank();

    uint256 expectedBorrowShares = amountBorrowed.toSharesUp(0, 0);

    vm.prank(BORROWER);
    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.Borrow(id, BORROWER, ONBEHALF, RECEIVER, amountBorrowed, expectedBorrowShares);
    (uint256 returnAssets, uint256 returnShares) = ardentis.borrow(marketParams, amountBorrowed, 0, ONBEHALF, RECEIVER);

    assertEq(returnAssets, amountBorrowed, "returned asset amount");
    assertEq(returnShares, expectedBorrowShares, "returned shares amount");
    assertEq(ardentis.position(id, ONBEHALF).borrowShares, expectedBorrowShares, "borrow shares");
    assertEq(ardentis.market(id).totalBorrowAssets, amountBorrowed, "total borrow");
    assertEq(ardentis.market(id).totalBorrowShares, expectedBorrowShares, "total borrow shares");
    assertEq(loanToken.balanceOf(RECEIVER), amountBorrowed, "borrower balance");
    assertEq(loanToken.balanceOf(address(ardentis)), amountSupplied - amountBorrowed, "ardentis balance");
  }

  function testBorrowSharesOnBehalf(
    uint256 amountCollateral,
    uint256 amountSupplied,
    uint256 sharesBorrowed,
    uint256 priceCollateral
  ) public {
    priceCollateral = bound(priceCollateral, MIN_COLLATERAL_PRICE, MAX_COLLATERAL_PRICE);
    sharesBorrowed = bound(sharesBorrowed, MIN_TEST_SHARES, MAX_TEST_SHARES);
    uint256 expectedAmountBorrowed = sharesBorrowed.toAssetsDown(0, 0);
    uint256 expectedBorrowedValue = sharesBorrowed.toAssetsUp(expectedAmountBorrowed, sharesBorrowed);
    uint256 minCollateral = expectedBorrowedValue.wDivUp(marketParams.lltv).mulDivUp(
      ORACLE_PRICE_SCALE,
      priceCollateral
    );
    vm.assume(minCollateral <= MAX_COLLATERAL_ASSETS);
    amountCollateral = bound(amountCollateral, minCollateral, MAX_COLLATERAL_ASSETS);
    vm.assume(amountCollateral <= type(uint256).max / priceCollateral);

    amountSupplied = bound(amountSupplied, expectedAmountBorrowed, MAX_TEST_AMOUNT);
    _supply(amountSupplied);

    oracle.setPrice(address(collateralToken), priceCollateral);

    collateralToken.setBalance(ONBEHALF, amountCollateral);

    vm.startPrank(ONBEHALF);
    collateralToken.approve(address(ardentis), amountCollateral);
    ardentis.supplyCollateral(marketParams, amountCollateral, ONBEHALF, hex"");
    // BORROWER is already authorized.
    vm.stopPrank();

    vm.prank(BORROWER);
    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.Borrow(id, BORROWER, ONBEHALF, RECEIVER, expectedAmountBorrowed, sharesBorrowed);
    (uint256 returnAssets, uint256 returnShares) = ardentis.borrow(marketParams, 0, sharesBorrowed, ONBEHALF, RECEIVER);

    assertEq(returnAssets, expectedAmountBorrowed, "returned asset amount");
    assertEq(returnShares, sharesBorrowed, "returned shares amount");
    assertEq(ardentis.position(id, ONBEHALF).borrowShares, sharesBorrowed, "borrow shares");
    assertEq(ardentis.market(id).totalBorrowAssets, expectedAmountBorrowed, "total borrow");
    assertEq(ardentis.market(id).totalBorrowShares, sharesBorrowed, "total borrow shares");
    assertEq(loanToken.balanceOf(RECEIVER), expectedAmountBorrowed, "borrower balance");
    assertEq(loanToken.balanceOf(address(ardentis)), amountSupplied - expectedAmountBorrowed, "ardentis balance");
  }
}
