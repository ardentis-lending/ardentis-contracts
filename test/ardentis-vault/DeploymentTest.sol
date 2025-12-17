// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./helpers/IntegrationTest.sol";

contract DeploymentTest is IntegrationTest {
  function testDeployArdentisVaultAddresssZero() public {
    vm.expectRevert(ErrorsLib.ZeroAddress.selector);
    new ArdentisVault(address(0), address(loanToken));
  }

  function testDeployArdentisVaultNotToken(address notToken) public {
    vm.assume(address(notToken) != address(loanToken));
    vm.assume(address(notToken) != address(collateralToken));
    vm.assume(address(notToken) != address(vault));

    ArdentisVault ardentisVaultImpl = new ArdentisVault(address(ardentis), address(loanToken));
    vm.expectRevert();
    new ERC1967Proxy(
      address(ardentisVaultImpl),
      abi.encodeWithSelector(
        ardentisVaultImpl.initialize.selector,
        OWNER,
        OWNER,
        ConstantsLib.MIN_TIMELOCK,
        notToken,
        "Ardentis Vault",
        "MMV"
      )
    );
  }

  function testDeployArdentisVault(
    address owner,
    address ardentis,
    uint256 initialTimelock,
    string memory name,
    string memory symbol
  ) public {
    assumeNotZeroAddress(owner);
    assumeNotZeroAddress(ardentis);
    initialTimelock = bound(initialTimelock, ConstantsLib.MIN_TIMELOCK, ConstantsLib.MAX_TIMELOCK);

    IArdentisVault newVault = createArdentisVault(owner, ardentis, address(loanToken), name, symbol);

    assertTrue(newVault.hasRole(MANAGER_ROLE, owner), "owner");
    assertEq(address(newVault.ARDENTIS()), ardentis, "ardentis");
    assertEq(newVault.asset(), address(loanToken), "asset");
    assertEq(newVault.name(), name, "name");
    assertEq(newVault.symbol(), symbol, "symbol");
    assertEq(loanToken.allowance(address(newVault), address(ardentis)), type(uint256).max, "loanToken allowance");
  }
}
