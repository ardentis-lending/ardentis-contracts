// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BaseTest.sol";

contract AccrueInterestIntegrationTest is BaseTest {
  using MathLib for uint256;
  using SharesMathLib for uint256;

  function testAccrueInterestMarketNotCreated(MarketParams memory marketParamsFuzz) public {
    vm.assume(neq(marketParamsFuzz, marketParams));

    vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
    ardentis.accrueInterest(marketParamsFuzz);
  }

  function testAccrueInterestIrmZero(MarketParams memory marketParamsFuzz, uint256 blocks) public {
    marketParamsFuzz.irm = address(0);
    marketParamsFuzz.lltv = 0;
    marketParamsFuzz.oracle = address(oracle);
    blocks = _boundBlocks(blocks);

    vm.startPrank(OWNER);
    ardentis.createMarket(marketParamsFuzz);
    vm.stopPrank();

    _forward(blocks);

    ardentis.accrueInterest(marketParamsFuzz);
  }

  function testAccrueInterestNoTimeElapsed(uint256 amountSupplied, uint256 amountBorrowed) public {
    uint256 collateralPrice = ardentis.getPrice(
      MarketParams({
        loanToken: address(loanToken),
        collateralToken: address(collateralToken),
        oracle: address(oracle),
        irm: address(irm),
        lltv: 0
      })
    );
    uint256 amountCollateral;
    (amountCollateral, amountBorrowed, ) = _boundHealthyPosition(amountCollateral, amountBorrowed, collateralPrice);
    amountSupplied = bound(amountSupplied, amountBorrowed, MAX_TEST_AMOUNT);

    loanToken.setBalance(address(this), amountSupplied);
    ardentis.supply(marketParams, amountSupplied, 0, address(this), hex"");

    collateralToken.setBalance(BORROWER, amountCollateral);

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, amountCollateral, BORROWER, hex"");
    ardentis.borrow(marketParams, amountBorrowed, 0, BORROWER, BORROWER);
    vm.stopPrank();

    uint256 totalBorrowBeforeAccrued = ardentis.market(id).totalBorrowAssets;
    uint256 totalSupplyBeforeAccrued = ardentis.market(id).totalSupplyAssets;
    uint256 totalSupplySharesBeforeAccrued = ardentis.market(id).totalSupplyShares;

    ardentis.accrueInterest(marketParams);

    assertEq(ardentis.market(id).totalBorrowAssets, totalBorrowBeforeAccrued, "total borrow");
    assertEq(ardentis.market(id).totalSupplyAssets, totalSupplyBeforeAccrued, "total supply");
    assertEq(ardentis.market(id).totalSupplyShares, totalSupplySharesBeforeAccrued, "total supply shares");
    assertEq(ardentis.position(id, FEE_RECIPIENT).supplyShares, 0, "feeRecipient's supply shares");
  }

  function testAccrueInterestNoBorrow(uint256 amountSupplied, uint256 blocks) public {
    amountSupplied = bound(amountSupplied, 2, MAX_TEST_AMOUNT);
    blocks = _boundBlocks(blocks);

    loanToken.setBalance(address(this), amountSupplied);
    ardentis.supply(marketParams, amountSupplied, 0, address(this), hex"");

    _forward(blocks);

    uint256 totalBorrowBeforeAccrued = ardentis.market(id).totalBorrowAssets;
    uint256 totalSupplyBeforeAccrued = ardentis.market(id).totalSupplyAssets;
    uint256 totalSupplySharesBeforeAccrued = ardentis.market(id).totalSupplyShares;

    ardentis.accrueInterest(marketParams);

    assertEq(ardentis.market(id).totalBorrowAssets, totalBorrowBeforeAccrued, "total borrow");
    assertEq(ardentis.market(id).totalSupplyAssets, totalSupplyBeforeAccrued, "total supply");
    assertEq(ardentis.market(id).totalSupplyShares, totalSupplySharesBeforeAccrued, "total supply shares");
    assertEq(ardentis.position(id, FEE_RECIPIENT).supplyShares, 0, "feeRecipient's supply shares");
    assertEq(ardentis.market(id).lastUpdate, block.timestamp, "last update");
  }

  function testAccrueInterestNoFee(uint256 amountSupplied, uint256 amountBorrowed, uint256 blocks) public {
    uint256 collateralPrice = ardentis.getPrice(
      MarketParams({
        loanToken: address(loanToken),
        collateralToken: address(collateralToken),
        oracle: address(oracle),
        irm: address(irm),
        lltv: 0
      })
    );
    uint256 amountCollateral;
    (amountCollateral, amountBorrowed, ) = _boundHealthyPosition(amountCollateral, amountBorrowed, collateralPrice);
    amountSupplied = bound(amountSupplied, amountBorrowed, MAX_TEST_AMOUNT);
    blocks = _boundBlocks(blocks);

    loanToken.setBalance(address(this), amountSupplied);
    loanToken.setBalance(address(this), amountSupplied);
    ardentis.supply(marketParams, amountSupplied, 0, address(this), hex"");

    collateralToken.setBalance(BORROWER, amountCollateral);

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, amountCollateral, BORROWER, hex"");

    ardentis.borrow(marketParams, amountBorrowed, 0, BORROWER, BORROWER);
    vm.stopPrank();

    _forward(blocks);

    uint256 borrowRate = (
      uint256(ardentis.market(id).totalBorrowAssets).wDivDown(ardentis.market(id).totalSupplyAssets)
    ) / 365 days;
    uint256 totalBorrowBeforeAccrued = ardentis.market(id).totalBorrowAssets;
    uint256 totalSupplyBeforeAccrued = ardentis.market(id).totalSupplyAssets;
    uint256 totalSupplySharesBeforeAccrued = ardentis.market(id).totalSupplyShares;
    uint256 expectedAccruedInterest = totalBorrowBeforeAccrued.wMulDown(
      borrowRate.wTaylorCompounded(blocks * BLOCK_TIME)
    );

    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.AccrueInterest(id, borrowRate, expectedAccruedInterest, 0);
    ardentis.accrueInterest(marketParams);

    assertEq(ardentis.market(id).totalBorrowAssets, totalBorrowBeforeAccrued + expectedAccruedInterest, "total borrow");
    assertEq(ardentis.market(id).totalSupplyAssets, totalSupplyBeforeAccrued + expectedAccruedInterest, "total supply");
    assertEq(ardentis.market(id).totalSupplyShares, totalSupplySharesBeforeAccrued, "total supply shares");
    assertEq(ardentis.position(id, FEE_RECIPIENT).supplyShares, 0, "feeRecipient's supply shares");
    assertEq(ardentis.market(id).lastUpdate, block.timestamp, "last update");
  }

  struct AccrueInterestWithFeesTestParams {
    uint256 borrowRate;
    uint256 totalBorrowBeforeAccrued;
    uint256 totalSupplyBeforeAccrued;
    uint256 totalSupplySharesBeforeAccrued;
    uint256 expectedAccruedInterest;
    uint256 feeAmount;
    uint256 feeShares;
  }

  function testAccrueInterestWithFees(
    uint256 amountSupplied,
    uint256 amountBorrowed,
    uint256 blocks,
    uint256 fee
  ) public {
    AccrueInterestWithFeesTestParams memory params;

    uint256 collateralPrice = ardentis.getPrice(
      MarketParams({
        loanToken: address(loanToken),
        collateralToken: address(collateralToken),
        oracle: address(oracle),
        irm: address(irm),
        lltv: 0
      })
    );
    uint256 amountCollateral;
    (amountCollateral, amountBorrowed, ) = _boundHealthyPosition(amountCollateral, amountBorrowed, collateralPrice);
    amountSupplied = bound(amountSupplied, amountBorrowed, MAX_TEST_AMOUNT);
    blocks = _boundBlocks(blocks);
    fee = bound(fee, 1, MAX_FEE);

    // Set fee parameters.
    vm.startPrank(OWNER);
    if (fee != ardentis.market(id).fee) ardentis.setFee(marketParams, fee);
    vm.stopPrank();

    loanToken.setBalance(address(this), amountSupplied);
    ardentis.supply(marketParams, amountSupplied, 0, address(this), hex"");

    collateralToken.setBalance(BORROWER, amountCollateral);

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, amountCollateral, BORROWER, hex"");
    ardentis.borrow(marketParams, amountBorrowed, 0, BORROWER, BORROWER);
    vm.stopPrank();

    _forward(blocks);

    params.borrowRate =
      (uint256(ardentis.market(id).totalBorrowAssets).wDivDown(ardentis.market(id).totalSupplyAssets)) /
      365 days;
    params.totalBorrowBeforeAccrued = ardentis.market(id).totalBorrowAssets;
    params.totalSupplyBeforeAccrued = ardentis.market(id).totalSupplyAssets;
    params.totalSupplySharesBeforeAccrued = ardentis.market(id).totalSupplyShares;
    params.expectedAccruedInterest = params.totalBorrowBeforeAccrued.wMulDown(
      params.borrowRate.wTaylorCompounded(blocks * BLOCK_TIME)
    );
    params.feeAmount = params.expectedAccruedInterest.wMulDown(fee);
    params.feeShares = params.feeAmount.toSharesDown(
      params.totalSupplyBeforeAccrued + params.expectedAccruedInterest - params.feeAmount,
      params.totalSupplySharesBeforeAccrued
    );

    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.AccrueInterest(id, params.borrowRate, params.expectedAccruedInterest, params.feeShares);
    ardentis.accrueInterest(marketParams);

    assertEq(
      ardentis.market(id).totalSupplyAssets,
      params.totalSupplyBeforeAccrued + params.expectedAccruedInterest,
      "total supply"
    );
    assertEq(
      ardentis.market(id).totalBorrowAssets,
      params.totalBorrowBeforeAccrued + params.expectedAccruedInterest,
      "total borrow"
    );
    assertEq(
      ardentis.market(id).totalSupplyShares,
      params.totalSupplySharesBeforeAccrued + params.feeShares,
      "total supply shares"
    );
    assertEq(ardentis.position(id, FEE_RECIPIENT).supplyShares, params.feeShares, "feeRecipient's supply shares");
    assertEq(ardentis.market(id).lastUpdate, block.timestamp, "last update");
  }
}
