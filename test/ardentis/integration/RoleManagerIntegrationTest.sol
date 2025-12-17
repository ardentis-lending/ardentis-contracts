// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BaseTest.sol";

contract RoleManagerIntegrationTest is BaseTest {
  using MathLib for uint256;

  function testDeployWithAddressZero() public {
    Ardentis ardentisImpl = new Ardentis();

    vm.expectRevert(bytes(ErrorsLib.ZERO_ADDRESS));
    new ERC1967Proxy(
      address(ardentisImpl),
      abi.encodeWithSelector(ardentisImpl.initialize.selector, address(0), address(0), address(0), 0)
    );
  }

  function testGrantRoleWhenNotAdmin(address addressFuzz) public {
    vm.assume(addressFuzz != OWNER);

    vm.prank(addressFuzz);

    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, addressFuzz, DEFAULT_ADMIN_ROLE)
    );
    Ardentis(address(ardentis)).grantRole(MANAGER, addressFuzz);
  }

  function testGrantRole(address newOwner) public {
    vm.assume(newOwner != OWNER);

    vm.startPrank(OWNER);
    vm.expectEmit(true, true, true, true, address(ardentis));
    emit IAccessControl.RoleGranted(MANAGER, newOwner, OWNER);
    Ardentis(address(ardentis)).grantRole(MANAGER, newOwner);
    vm.stopPrank();

    assertTrue(Ardentis(address(ardentis)).hasRole(MANAGER, newOwner), "owner is not set");
  }

  function testEnableIrmWhenNotOwner(address addressFuzz, address irmFuzz) public {
    vm.assume(addressFuzz != OWNER);
    vm.assume(irmFuzz != address(irm));

    vm.prank(addressFuzz);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, addressFuzz, MANAGER)
    );
    ardentis.enableIrm(irmFuzz);
  }

  function testEnableIrmAlreadySet() public {
    vm.prank(OWNER);
    vm.expectRevert(bytes(ErrorsLib.ALREADY_SET));
    ardentis.enableIrm(address(irm));
  }

  function testEnableIrm(address irmFuzz) public {
    vm.assume(!ardentis.isIrmEnabled(irmFuzz));

    vm.prank(OWNER);
    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.EnableIrm(irmFuzz);
    ardentis.enableIrm(irmFuzz);

    assertTrue(ardentis.isIrmEnabled(irmFuzz), "IRM is not enabled");
  }

  function testEnableLltvWhenNotOwner(address addressFuzz, uint256 lltvFuzz) public {
    vm.assume(addressFuzz != OWNER);
    vm.assume(lltvFuzz != marketParams.lltv);

    vm.prank(addressFuzz);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, addressFuzz, MANAGER)
    );
    ardentis.enableLltv(lltvFuzz);
  }

  function testEnableLltvAlreadySet() public {
    vm.prank(OWNER);
    vm.expectRevert(bytes(ErrorsLib.ALREADY_SET));
    ardentis.enableLltv(marketParams.lltv);
  }

  function testEnableTooHighLltv(uint256 lltv) public {
    lltv = bound(lltv, WAD, type(uint256).max);

    vm.prank(OWNER);
    vm.expectRevert(bytes(ErrorsLib.MAX_LLTV_EXCEEDED));
    ardentis.enableLltv(lltv);
  }

  function testEnableLltv(uint256 lltvFuzz) public {
    lltvFuzz = _boundValidLltv(lltvFuzz);

    vm.assume(!ardentis.isLltvEnabled(lltvFuzz));

    vm.prank(OWNER);
    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.EnableLltv(lltvFuzz);
    ardentis.enableLltv(lltvFuzz);

    assertTrue(ardentis.isLltvEnabled(lltvFuzz), "LLTV is not enabled");
  }

  function testSetFeeWhenNotOwner(address addressFuzz, uint256 feeFuzz) public {
    vm.assume(addressFuzz != OWNER);

    vm.prank(addressFuzz);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, addressFuzz, MANAGER)
    );
    ardentis.setFee(marketParams, feeFuzz);
  }

  function testSetFeeWhenMarketNotCreated(MarketParams memory marketParamsFuzz, uint256 feeFuzz) public {
    vm.assume(neq(marketParamsFuzz, marketParams));

    vm.prank(OWNER);
    vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
    ardentis.setFee(marketParamsFuzz, feeFuzz);
  }

  function testSetTooHighFee(uint256 feeFuzz) public {
    feeFuzz = bound(feeFuzz, MAX_FEE + 1, type(uint256).max);

    vm.prank(OWNER);
    vm.expectRevert(bytes(ErrorsLib.MAX_FEE_EXCEEDED));
    ardentis.setFee(marketParams, feeFuzz);
  }

  function testSetFee(uint256 feeFuzz) public {
    feeFuzz = bound(feeFuzz, 1, MAX_FEE);

    vm.prank(OWNER);
    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.SetFee(id, feeFuzz);
    ardentis.setFee(marketParams, feeFuzz);

    assertEq(ardentis.market(id).fee, feeFuzz);
  }

  function testSetFeeRecipientWhenNotOwner(address addressFuzz) public {
    vm.assume(addressFuzz != OWNER);

    vm.prank(addressFuzz);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, addressFuzz, MANAGER)
    );
    ardentis.setFeeRecipient(addressFuzz);
  }

  function testSetFeeRecipient(address newFeeRecipient) public {
    vm.assume(newFeeRecipient != ardentis.feeRecipient());

    vm.prank(OWNER);
    vm.expectEmit(true, true, true, true, address(ardentis));
    emit EventsLib.SetFeeRecipient(newFeeRecipient);
    ardentis.setFeeRecipient(newFeeRecipient);

    assertEq(ardentis.feeRecipient(), newFeeRecipient);
  }
}
