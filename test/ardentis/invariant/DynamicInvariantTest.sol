// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./BaseInvariantTest.sol";

contract DynamicInvariantTest is BaseInvariantTest {
  using MarketParamsLib for MarketParams;

  uint256 internal immutable MIN_PRICE = ORACLE_PRICE_SCALE / 10;
  uint256 internal immutable MAX_PRICE = ORACLE_PRICE_SCALE * 10;

  function setUp() public virtual override {
    selectors.push(this.liquidateSeizedAssetsNoRevert.selector);
    selectors.push(this.liquidateRepaidSharesNoRevert.selector);
    selectors.push(this.setFeeNoRevert.selector);
    selectors.push(this.setPrice.selector);
    selectors.push(this.mine.selector);

    super.setUp();
  }

  /* HANDLERS */

  function setPrice(uint256 price) external {
    price = bound(price, MIN_PRICE, MAX_PRICE);

    oracle.setPrice(address(collateralToken), price);
    oracle.setPrice(address(loanToken), price);
  }

  /* INVARIANTS */

  function invariantSupplyShares() public view {
    address[] memory users = targetSenders();

    for (uint256 i; i < allMarketParams.length; ++i) {
      MarketParams memory _marketParams = allMarketParams[i];
      Id _id = _marketParams.id();

      uint256 sumSupplyShares = ardentis.position(_id, FEE_RECIPIENT).supplyShares;
      for (uint256 j; j < users.length; ++j) {
        sumSupplyShares += ardentis.position(_id, users[j]).supplyShares;
      }

      assertEq(sumSupplyShares, ardentis.market(_id).totalSupplyShares, vm.toString(_marketParams.lltv));
    }
  }

  function invariantBorrowShares() public view {
    address[] memory users = targetSenders();

    for (uint256 i; i < allMarketParams.length; ++i) {
      MarketParams memory _marketParams = allMarketParams[i];
      Id _id = _marketParams.id();

      uint256 sumBorrowShares;
      for (uint256 j; j < users.length; ++j) {
        sumBorrowShares += ardentis.position(_id, users[j]).borrowShares;
      }

      assertEq(sumBorrowShares, ardentis.market(_id).totalBorrowShares, vm.toString(_marketParams.lltv));
    }
  }

  function invariantTotalSupplyGeTotalBorrow() public view {
    for (uint256 i; i < allMarketParams.length; ++i) {
      MarketParams memory _marketParams = allMarketParams[i];
      Id _id = _marketParams.id();

      assertGe(ardentis.market(_id).totalSupplyAssets, ardentis.market(_id).totalBorrowAssets);
    }
  }

  function invariantArdentisBalance() public view {
    for (uint256 i; i < allMarketParams.length; ++i) {
      MarketParams memory _marketParams = allMarketParams[i];
      Id _id = _marketParams.id();

      assertGe(
        loanToken.balanceOf(address(ardentis)) + ardentis.market(_id).totalBorrowAssets,
        ardentis.market(_id).totalSupplyAssets
      );
    }
  }

  function invariantBadDebt() public view {
    address[] memory users = targetSenders();

    for (uint256 i; i < allMarketParams.length; ++i) {
      MarketParams memory _marketParams = allMarketParams[i];
      Id _id = _marketParams.id();

      for (uint256 j; j < users.length; ++j) {
        address user = users[j];

        if (ardentis.position(_id, user).collateral == 0) {
          assertEq(
            ardentis.position(_id, user).borrowShares,
            0,
            string.concat(vm.toString(_marketParams.lltv), ":", vm.toString(user))
          );
        }
      }
    }
  }
}
