pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import { ETHProvider } from "../../src/provider/ETHProvider.sol";
import { Ardentis } from "../../src/ardentis/Ardentis.sol";
import { ArdentisVault } from "../../src/ardentis-vault/ArdentisVault.sol";
import { MarketParams, Id } from "ardentis/interfaces/IArdentis.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";
import { SharesMathLib } from "ardentis/libraries/SharesMathLib.sol";

contract ETHProviderTest is Test {
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;

  ETHProvider ethProvider;
  address ardentisProxy = 0xf820fB4680712CD7263a0D3D024D5b5aEA82Fd70;
  Ardentis ardentis = Ardentis(ardentisProxy);
  ArdentisVault ardentisVault;
  address ardentisVaultProxy;

  address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  address admin = 0xa18ae79AEDA3e711E0CD64cfe1Cd06402d400D61; // timelock
  address manager = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
  address irm = 0x8b7d334d243b74D63C4b963893267A0F5240F990;
  address USD1 = 0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d;
  address multiOracle = 0xA64FE284EB8279B9b63946DD51813b0116099301;

  uint256 lltv86 = 86 * 1e16;

  address user = makeAddr("user");
  address user2 = makeAddr("user22");
  MarketParams param =
    MarketParams({ loanToken: USD1, collateralToken: WETH, oracle: multiOracle, irm: irm, lltv: lltv86 });

  function setUp() public {
    vm.createSelectFork(vm.envString("ETH_RPC"), 23566432);

    // Deploy ETHProvider
    ETHProvider ethProviderImpl = new ETHProvider(address(ardentis), WETH);
    address ethProviderProxy = address(
      new ERC1967Proxy(
        address(ethProviderImpl),
        abi.encodeWithSelector(ethProviderImpl.initialize.selector, admin, manager)
      )
    );
    ethProvider = ETHProvider(payable(ethProviderProxy));

    // Set up Ardentis
    vm.prank(manager);
    ardentis.addProvider(param.id(), ethProviderProxy);
    assertEq(ardentis.providers(param.id(), WETH), ethProviderProxy);

    // Deploy ArdentisVault
    ArdentisVault ardentisVaultImpl = new ArdentisVault(address(ardentis), WETH);
    ardentisVaultProxy = address(
      new ERC1967Proxy(
        address(ardentisVaultImpl),
        abi.encodeWithSelector(
          ardentisVaultImpl.initialize.selector,
          address(this),
          address(this),
          WETH,
          "ardentis vault",
          "ardentis"
        )
      )
    );
    ardentisVault = ArdentisVault(ardentisVaultProxy);

    ardentisVault.grantRole(ardentisVault.CURATOR(), address(this));
  }

  function test_initialize() public view {
    assertEq(address(ethProvider.ARDENTIS()), ardentisProxy);
    assertEq(address(ethProvider.TOKEN()), WETH);

    assertEq(ethProvider.hasRole(ethProvider.DEFAULT_ADMIN_ROLE(), admin), true);
    assertEq(ethProvider.hasRole(ethProvider.MANAGER(), manager), true);
  }

  function skip_test_deposit() public {
    vm.prank(manager);
    ethProvider.addVault(ardentisVaultProxy);
    deal(user, 100 ether);

    uint256 ethBalanceBefore = user.balance;
    uint256 wethBalanceBefore = IERC20(WETH).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = ethProvider.deposit{ value: 1 ether }(ardentisVaultProxy, user);
    assertEq(shares, expectShares);

    assertEq(user.balance, ethBalanceBefore - 1 ether);
    assertEq(ardentisVault.balanceOf(user), expectShares);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(IERC20(WETH).balanceOf(ardentisVaultProxy), 0);
    assertEq(IERC20(WETH).balanceOf(ardentisProxy), wethBalanceBefore + 1 ether);
  }

  function skip_test_mint() public {
    vm.prank(manager);
    ethProvider.addVault(ardentisVaultProxy);
    deal(user, 100 ether);

    uint256 ethBalanceBefore = user.balance;
    uint256 wethBalanceBefore = IERC20(WETH).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectAsset = ardentisVault.previewMint(1 ether);
    uint256 assets = ethProvider.mint{ value: expectAsset }(ardentisVaultProxy, 1 ether, user);

    assertEq(assets, expectAsset);
    assertEq(user.balance, ethBalanceBefore - expectAsset);
    assertEq(ardentisVault.balanceOf(user), 1 ether);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(IERC20(WETH).balanceOf(ardentisProxy), wethBalanceBefore + expectAsset);
  }

  function skip_test_mint_excess() public {
    vm.prank(manager);
    ethProvider.addVault(ardentisVaultProxy);
    deal(user, 100 ether);

    uint256 ethBalanceBefore = user.balance;
    uint256 wethBalanceBefore = IERC20(WETH).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectAsset = ardentisVault.previewMint(1 ether);
    uint256 assets = ethProvider.mint{ value: expectAsset + 1 }(ardentisVaultProxy, 1 ether, user);

    assertEq(assets, expectAsset);
    assertEq(user.balance, ethBalanceBefore - expectAsset);
    assertEq(ardentisVault.balanceOf(user), 1 ether);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(IERC20(WETH).balanceOf(ardentisProxy), wethBalanceBefore + expectAsset);
  }

  function skip_test_withdraw() public {
    skip_test_deposit();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = ethProvider.withdraw(ardentisVaultProxy, 1 ether, payable(user), user);

    assertApproxEqAbs(shares, expectShares, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(user.balance, balanceBefore + 1 ether);
    assertEq(ardentisVault.totalAssets(), totalAssets - 1 ether);
  }

  function skip_test_redeem() public {
    skip_test_deposit();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 shares = ardentisVault.convertToShares(1 ether);
    uint256 assets = ethProvider.redeem(ardentisVaultProxy, shares, payable(user), user);

    assertApproxEqAbs(assets, 1 ether, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertApproxEqAbs(user.balance, balanceBefore + 1 ether, 1);
    assertApproxEqAbs(ardentisVault.totalAssets(), totalAssets - 1 ether, 1);
  }

  function skip_test_redeem_all() public {
    skip_test_deposit();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 shares = sharesBefore;
    uint256 expectAssets = ardentisVault.convertToAssets(shares);
    uint256 assets = ethProvider.redeem(ardentisVaultProxy, shares, payable(user), user);

    assertEq(assets, expectAssets);
    assertEq(ardentisVault.balanceOf(user), 0);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(user.balance, balanceBefore + assets);
    assertEq(ardentisVault.totalAssets(), totalAssets - assets);
  }

  function test_supplyCollateral() public {
    vm.prank(manager);
    ethProvider.addVault(ardentisVaultProxy);
    deal(user, 100 ether);

    uint256 ethBalanceBefore = user.balance;
    vm.startPrank(user);
    vm.expectRevert("callback not supported");
    ethProvider.supplyCollateral{ value: 1 ether }(param, user, bytes("foo"));
    ethProvider.supplyCollateral{ value: 1 ether }(param, user, "");

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 1 ether);
    assertEq(user.balance, ethBalanceBefore - 1 ether);
  }

  function test_withdrawCollateral() public {
    test_supplyCollateral();

    uint256 ethBalanceBefore = user.balance;
    vm.startPrank(user);
    ethProvider.withdrawCollateral(param, 1 ether, user, payable(user));

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 0);
    assertEq(user.balance, ethBalanceBefore + 1 ether);
  }

  function test_withdrawCollateral_onBehalf() public {
    test_supplyCollateral();
    vm.stopPrank();

    uint256 ethBalanceBefore = user2.balance;
    vm.prank(user);
    ardentis.setAuthorization(user2, true);

    vm.startPrank(user2);
    ethProvider.withdrawCollateral(param, 1 ether, user, payable(user2));

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 0);
    assertEq(user2.balance, ethBalanceBefore + 1 ether);
  }

  function test_borrow_usd1() public {
    test_supplyCollateral();

    uint256 balanceBefore = IERC20(USD1).balanceOf(user);
    vm.startPrank(user);
    vm.expectRevert("invalid loan token");
    ethProvider.borrow(param, 20 ether, 0, user, payable(user));
    ardentis.borrow(param, 20 ether, 0, user, payable(user));

    uint256 assets = 20 ether; // 20 USD1
    (, , uint128 totalBorrowAssets, uint128 totalBorrowShares, , ) = ardentis.market(param.id());

    uint256 shares = assets.toSharesUp(totalBorrowAssets, totalBorrowShares);
    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, shares);
    assertEq(collateral, 1 ether);
    assertEq(IERC20(USD1).balanceOf(user), balanceBefore + assets);
  }

  function test_borrow_usd1_onBehalf() public {
    test_supplyCollateral();
    vm.stopPrank();

    uint256 balanceBefore = IERC20(USD1).balanceOf(user2);
    vm.prank(user);
    ardentis.setAuthorization(user2, true);

    vm.startPrank(user2);
    vm.expectRevert("invalid loan token");
    ethProvider.borrow(param, 1 ether, 0, user, payable(user2));
    ardentis.borrow(param, 20 ether, 0, user, payable(user2));

    uint256 assets = 20 ether; // 20 USD1
    (, , uint128 totalBorrowAssets, uint128 totalBorrowShares, , ) = ardentis.market(param.id());

    uint256 shares = assets.toSharesUp(totalBorrowAssets, totalBorrowShares);
    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, shares);
    assertEq(collateral, 1 ether);
    assertEq(IERC20(USD1).balanceOf(user2), balanceBefore + assets);
  }

  function test_repay() public {
    deal(USD1, user, 100 ether);
    test_borrow_usd1();

    skip(1 days);

    ardentis.accrueInterest(param);
    vm.startPrank(user);
    (, uint128 borrowSharesBefore, ) = ardentis.position(param.id(), user);
    (, , uint128 totalBorrowAssets, uint128 totalBorrowShares, , ) = ardentis.market(param.id());
    uint256 assets = uint256(borrowSharesBefore).toAssetsUp(totalBorrowAssets, totalBorrowShares);
    uint256 balanceBefore = IERC20(USD1).balanceOf(user);
    vm.expectRevert("invalid loan token");
    ethProvider.repay{ value: 0 }(param, 0, borrowSharesBefore, user, "");

    IERC20(USD1).approve(address(ardentis), type(uint256).max);
    ardentis.repay(param, 0, borrowSharesBefore, user, "");

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 1 ether);
    assertEq(IERC20(USD1).balanceOf(user), balanceBefore - assets);
  }

  function test_addVault() public {
    ArdentisVault newVaultImpl = new ArdentisVault(ardentisProxy, WETH);
    address newVaultProxy = address(
      new ERC1967Proxy(
        address(newVaultImpl),
        abi.encodeWithSelector(newVaultImpl.initialize.selector, admin, manager, WETH, "new vault", "new vault")
      )
    );
    vm.startPrank(manager);
    ethProvider.addVault(newVaultProxy);
    vm.stopPrank();

    assertEq(ethProvider.vaults(newVaultProxy), true, "add vault failed");
  }

  function test_removeVault() public {
    vm.startPrank(manager);
    ethProvider.addVault(ardentisVaultProxy);
    ethProvider.removeVault(ardentisVaultProxy);
    vm.stopPrank();

    assertEq(ethProvider.vaults(ardentisVaultProxy), false, "remove vault failed");
  }

  function skip_test_depositNotInVaults() public {
    deal(user, 100 ether);

    vm.startPrank(manager);
    ethProvider.removeVault(ardentisVaultProxy);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(bytes("vault not added"));
    ethProvider.deposit{ value: 1 ether }(ardentisVaultProxy, user);

    vm.expectRevert(bytes("vault not added"));
    ethProvider.mint{ value: 1 ether }(ardentisVaultProxy, 1 ether, user);
    vm.stopPrank();
  }

  function skip_test_withdrawNotInVaults() public {
    skip_test_deposit();

    ethProvider.deposit{ value: 1 ether }(ardentisVaultProxy, user);

    vm.startPrank(manager);
    ethProvider.removeVault(ardentisVaultProxy);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(bytes("vault not added"));
    ethProvider.withdraw(ardentisVaultProxy, 1 ether, payable(user), user);

    uint256 shares = ardentisVault.balanceOf(user);
    vm.expectRevert(bytes("vault not added"));
    ethProvider.redeem(ardentisVaultProxy, shares, payable(user), user);
    vm.stopPrank();
  }

  function skip_test_depositInVaults() public {
    deal(user, 100 ether);

    uint256 ethBalanceBefore = user.balance;
    uint256 wethBalanceBefore = IERC20(WETH).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = ethProvider.deposit{ value: 1 ether }(ardentisVaultProxy, user);
    assertEq(shares, expectShares);

    assertEq(user.balance, ethBalanceBefore - 1 ether);
    assertEq(ardentisVault.balanceOf(user), expectShares);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(IERC20(WETH).balanceOf(ardentisVaultProxy), 0);
    assertEq(IERC20(WETH).balanceOf(ardentisProxy), wethBalanceBefore + 1 ether);
  }

  function skip_test_mintInVaults() public {
    deal(user, 100 ether);

    uint256 ethBalanceBefore = user.balance;
    uint256 wethBalanceBefore = IERC20(WETH).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectAsset = ardentisVault.previewMint(1 ether);
    uint256 assets = ethProvider.mint{ value: expectAsset }(ardentisVaultProxy, 1 ether, user);

    assertEq(assets, expectAsset);
    assertEq(user.balance, ethBalanceBefore - expectAsset);
    assertEq(ardentisVault.balanceOf(user), 1 ether);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(IERC20(WETH).balanceOf(ardentisProxy), wethBalanceBefore + expectAsset);
  }

  function skip_test_withdrawInVaults() public {
    skip_test_depositInVaults();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = ethProvider.withdraw(ardentisVaultProxy, 1 ether, payable(user), user);

    assertApproxEqAbs(shares, expectShares, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertEq(user.balance, balanceBefore + 1 ether);
    assertEq(ardentisVault.totalAssets(), totalAssets - 1 ether);
  }

  function skip_test_redeemInVaults() public {
    skip_test_depositInVaults();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 shares = ardentisVault.convertToShares(1 ether);
    uint256 assets = ethProvider.redeem(ardentisVaultProxy, shares, payable(user), user);

    assertApproxEqAbs(assets, 1 ether, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(ethProvider)), 0);
    assertApproxEqAbs(user.balance, balanceBefore + 1 ether, 1);
    assertApproxEqAbs(ardentisVault.totalAssets(), totalAssets - 1 ether, 1);
  }
}
