// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MarketParams } from "ardentis/interfaces/IArdentis.sol";
import "../BaseTest.sol";

contract WhitelistTest is BaseTest {
  using MarketParamsLib for MarketParams;
  address whitelist;
  function setUp() public override {
    super.setUp();
    whitelist = makeAddr("whitelist");
  }

  function testAddWhitelist() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);
    ardentis.addLiquidationWhitelist(id, whitelist);
    assertEq(ardentis.getLiquidationWhitelist(id).length, 1, "whitelist length");
    assertTrue(ardentis.isLiquidationWhitelist(id, whitelist), "whitelist");

    vm.expectRevert(bytes(ErrorsLib.ALREADY_SET));
    ardentis.addLiquidationWhitelist(id, whitelist);

    vm.stopPrank();
  }

  function testRemoveWhitelist() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);
    vm.expectRevert(bytes(ErrorsLib.NOT_SET));
    ardentis.removeLiquidationWhitelist(id, whitelist);

    ardentis.addLiquidationWhitelist(id, whitelist);
    assertEq(ardentis.getLiquidationWhitelist(id).length, 1, "whitelist length");
    assertTrue(ardentis.isLiquidationWhitelist(id, whitelist), "whitelist");

    ardentis.removeLiquidationWhitelist(id, whitelist);
    assertEq(ardentis.getLiquidationWhitelist(id).length, 0, "whitelist length");
    assertTrue(ardentis.isLiquidationWhitelist(id, whitelist), "whitelist");
    vm.stopPrank();
  }

  function testNotWhiteListLiquidate() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);

    ardentis.addLiquidationWhitelist(id, whitelist);
    assertEq(ardentis.getLiquidationWhitelist(id).length, 1, "whitelist length");
    assertTrue(ardentis.isLiquidationWhitelist(id, whitelist), "whitelist");

    vm.expectRevert(bytes(ErrorsLib.NOT_LIQUIDATION_WHITELIST));
    ardentis.liquidate(marketParams, BORROWER, 0, 0, "");

    vm.stopPrank();
  }

  function testAddAlphaWhiteList() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);
    ardentis.addWhiteList(id, whitelist);
    assertEq(ardentis.getWhiteList(id).length, 1, "whitelist length");
    assertTrue(ardentis.isWhiteList(id, whitelist), "whitelist");

    vm.expectRevert(bytes(ErrorsLib.ALREADY_SET));
    ardentis.addWhiteList(id, whitelist);

    vm.stopPrank();
  }

  function testRemoveAlphaWhiteList() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);
    vm.expectRevert(bytes(ErrorsLib.NOT_SET));
    ardentis.removeWhiteList(id, whitelist);

    ardentis.addWhiteList(id, whitelist);
    assertEq(ardentis.getWhiteList(id).length, 1, "whitelist length");
    assertTrue(ardentis.isWhiteList(id, whitelist), "whitelist");

    ardentis.removeWhiteList(id, whitelist);
    assertEq(ardentis.getWhiteList(id).length, 0, "whitelist length");
    assertTrue(ardentis.isWhiteList(id, whitelist), "whitelist");
    vm.stopPrank();
  }

  function testNotWhiteListBorrow() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);

    ardentis.addWhiteList(id, whitelist);
    assertEq(ardentis.getWhiteList(id).length, 1, "whitelist length");
    assertTrue(ardentis.isWhiteList(id, whitelist), "whitelist");

    vm.expectRevert(bytes(ErrorsLib.NOT_WHITELIST));
    ardentis.borrow(marketParams, 10 ether, 0, BORROWER, BORROWER);

    vm.stopPrank();
  }

  function testNotWhiteListSupply() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);

    ardentis.addWhiteList(id, whitelist);
    assertEq(ardentis.getWhiteList(id).length, 1, "whitelist length");
    assertTrue(ardentis.isWhiteList(id, whitelist), "whitelist");

    vm.expectRevert(bytes(ErrorsLib.NOT_WHITELIST));
    ardentis.supply(marketParams, 10 ether, 0, BORROWER, "");

    vm.stopPrank();
  }

  function testNotWhiteListSupplyCollateral() public {
    Id id = marketParams.id();
    vm.startPrank(OWNER);

    ardentis.addWhiteList(id, whitelist);
    assertEq(ardentis.getWhiteList(id).length, 1, "whitelist length");
    assertTrue(ardentis.isWhiteList(id, whitelist), "whitelist");

    vm.expectRevert(bytes(ErrorsLib.NOT_WHITELIST));
    ardentis.supplyCollateral(marketParams, 10 ether, SUPPLIER, "");

    vm.stopPrank();
  }

  function testWhiteListOperation() public {
    loanToken.setBalance(SUPPLIER, 100 ether);
    collateralToken.setBalance(BORROWER, 100 ether);
    oracle.setPrice(address(loanToken), 1e8);
    oracle.setPrice(address(collateralToken), 1e8);

    Id id = marketParams.id();
    vm.startPrank(OWNER);
    ardentis.addWhiteList(id, SUPPLIER);
    ardentis.addWhiteList(id, BORROWER);
    vm.stopPrank();

    vm.startPrank(SUPPLIER);
    ardentis.supply(marketParams, 100 ether, 0, SUPPLIER, "");
    vm.stopPrank();

    vm.startPrank(BORROWER);
    ardentis.supplyCollateral(marketParams, 100 ether, BORROWER, "");
    ardentis.borrow(marketParams, 80 ether, 0, BORROWER, BORROWER);
    ardentis.repay(marketParams, 80 ether, 0, BORROWER, "");
    vm.stopPrank();
  }
}
