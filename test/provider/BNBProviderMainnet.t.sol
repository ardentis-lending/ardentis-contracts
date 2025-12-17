pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import { BNBProvider } from "../../src/provider/BNBProvider.sol";
import { Ardentis } from "../../src/ardentis/Ardentis.sol";
import { ArdentisVault } from "../../src/ardentis-vault/ArdentisVault.sol";
import { MarketParams, Id } from "ardentis/interfaces/IArdentis.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";
import { SharesMathLib } from "ardentis/libraries/SharesMathLib.sol";

contract BNBProviderTest is Test {
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;

  bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  BNBProvider bnbProvider = BNBProvider(payable(0x367384C54756a25340c63057D87eA22d47Fd5701)); // Ardentis WBNB BNBProvider
  ArdentisVault ardentisVault; // WBNB Vault
  Ardentis ardentis;

  address ardentisProxy = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C; // ArdentisProxy
  address ardentisVaultProxy = 0x57134a64B7cD9F9eb72F8255A671F5Bf2fe3E2d0; // ArdentisVaultProxy

  address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  address admin = 0x07D274a68393E8b8a2CCf19A2ce4Ba3518735253; // timelock
  address manager = 0x8d388136d578dCD791D081c6042284CED6d9B0c6;
  address irm = 0xFe7dAe87Ebb11a7BEB9F534BB23267992d9cDe7c;
  address BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
  address USD1 = 0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d;
  address multiOracle = 0xf3afD82A4071f272F403dC176916141f44E6c750;

  uint256 lltv70 = 70 * 1e16;
  uint256 lltv80 = 80 * 1e16;

  address user = makeAddr("user");
  address user2 = makeAddr("user22");

  function setUp() public {
    vm.createSelectFork(vm.envString("BSC_RPC"), 60541406);

    // Upgrade ArdentisVault
    address newImlp = address(new ArdentisVault(ardentisProxy, WBNB));
    address oldImpl = 0x0E52472cc585F8E28322CA4536eBd7094431C610;
    vm.startPrank(admin);
    UUPSUpgradeable proxy2 = UUPSUpgradeable(ardentisVaultProxy);
    proxy2.upgradeToAndCall(newImlp, bytes(""));
    assertEq(getImplementation(ardentisVaultProxy), newImlp);
    vm.stopPrank();
    ardentisVault = ArdentisVault(ardentisVaultProxy);

    // Upgrade Ardentis
    newImlp = address(new Ardentis());
    oldImpl = 0x0Cc33Db59a51aaC837790dfb8f8Cd07F7f16d779;
    vm.startPrank(admin);
    UUPSUpgradeable proxy3 = UUPSUpgradeable(ardentisProxy);
    proxy3.upgradeToAndCall(newImlp, bytes(""));
    assertEq(getImplementation(ardentisProxy), newImlp);
    vm.stopPrank();
    ardentis = Ardentis(ardentisProxy);

    // Upgrade BNBProvider
    newImlp = address(new BNBProvider(ardentisProxy, ardentisVaultProxy, WBNB));
    vm.startPrank(admin);
    UUPSUpgradeable proxy1 = UUPSUpgradeable(address(bnbProvider));
    proxy1.upgradeToAndCall(newImlp, bytes(""));
    assertEq(getImplementation(address(bnbProvider)), newImlp);
    vm.stopPrank();

    MarketParams memory param1 = MarketParams({
      loanToken: WBNB,
      collateralToken: BTCB,
      oracle: multiOracle,
      irm: irm,
      lltv: lltv80
    });

    MarketParams memory param2 = MarketParams({
      loanToken: USD1,
      collateralToken: WBNB,
      oracle: multiOracle,
      irm: irm,
      lltv: lltv70
    });

    // Set up Ardentis
    vm.startPrank(manager);
    assertEq(ardentis.providers(param1.id(), WBNB), address(bnbProvider));
    assertEq(ardentis.providers(param2.id(), WBNB), address(bnbProvider));
    vm.stopPrank();

    // Set up ArdentisVault
    assertEq(ardentisVault.provider(), address(bnbProvider));
  }

  function test_initialize() public {
    assertEq(address(bnbProvider.ARDENTIS()), ardentisProxy);
    assertEq(address(bnbProvider.ARDENTIS_VAULT()), ardentisVaultProxy);
    assertEq(address(bnbProvider.TOKEN()), WBNB);

    assertEq(bnbProvider.hasRole(bnbProvider.DEFAULT_ADMIN_ROLE(), admin), true);
    assertEq(bnbProvider.hasRole(bnbProvider.MANAGER(), manager), true);
  }

  function test_deposit() public {
    deal(user, 100 ether);

    uint256 bnbBalanceBefore = user.balance;
    uint256 wbnbBalanceBefore = IERC20(WBNB).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = bnbProvider.deposit{ value: 1 ether }(user);
    assertEq(shares, expectShares);

    assertEq(user.balance, bnbBalanceBefore - 1 ether);
    assertEq(ardentisVault.balanceOf(user), expectShares);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(IERC20(WBNB).balanceOf(ardentisVaultProxy), 0);
    assertEq(IERC20(WBNB).balanceOf(ardentisProxy), wbnbBalanceBefore + 1 ether);
  }

  function test_mint() public {
    deal(user, 100 ether);

    uint256 bnbBalanceBefore = user.balance;
    uint256 wbnbBalanceBefore = IERC20(WBNB).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectAsset = ardentisVault.previewMint(1 ether);
    uint256 assets = bnbProvider.mint{ value: expectAsset }(1 ether, user);

    assertEq(assets, expectAsset);
    assertEq(user.balance, bnbBalanceBefore - expectAsset);
    assertEq(ardentisVault.balanceOf(user), 1 ether);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(IERC20(WBNB).balanceOf(ardentisProxy), wbnbBalanceBefore + expectAsset);
  }

  function test_mint_excess() public {
    deal(user, 100 ether);

    uint256 bnbBalanceBefore = user.balance;
    uint256 wbnbBalanceBefore = IERC20(WBNB).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectAsset = ardentisVault.previewMint(1 ether);
    uint256 assets = bnbProvider.mint{ value: expectAsset + 1 }(1 ether, user);

    assertEq(assets, expectAsset);
    assertEq(user.balance, bnbBalanceBefore - expectAsset);
    assertEq(ardentisVault.balanceOf(user), 1 ether);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(IERC20(WBNB).balanceOf(ardentisProxy), wbnbBalanceBefore + expectAsset);
  }

  function test_withdraw() public {
    test_deposit();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = bnbProvider.withdraw(1 ether, payable(user), user);

    assertApproxEqAbs(shares, expectShares, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(user.balance, balanceBefore + 1 ether);
    assertEq(ardentisVault.totalAssets(), totalAssets - 1 ether);
  }

  function test_redeem() public {
    test_deposit();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 shares = ardentisVault.convertToShares(1 ether);
    uint256 assets = bnbProvider.redeem(shares, payable(user), user);

    assertApproxEqAbs(assets, 1 ether, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertApproxEqAbs(user.balance, balanceBefore + 1 ether, 1);
    assertApproxEqAbs(ardentisVault.totalAssets(), totalAssets - 1 ether, 1);
  }

  function test_redeem_all() public {
    test_deposit();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 shares = sharesBefore;
    uint256 expectAssets = ardentisVault.convertToAssets(shares);
    uint256 assets = bnbProvider.redeem(shares, payable(user), user);

    assertEq(assets, expectAssets);
    assertEq(ardentisVault.balanceOf(user), 0);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(user.balance, balanceBefore + assets);
    assertEq(ardentisVault.totalAssets(), totalAssets - assets);
  }

  function test_supplyCollateral() public returns (MarketParams memory) {
    deal(user, 100 ether);

    MarketParams memory param = MarketParams({
      loanToken: USD1,
      collateralToken: WBNB,
      oracle: multiOracle,
      irm: irm,
      lltv: lltv70
    });

    uint256 bnbBalanceBefore = user.balance;
    vm.startPrank(user);
    bnbProvider.supplyCollateral{ value: 1 ether }(param, user, "");

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 1 ether);
    assertEq(user.balance, bnbBalanceBefore - 1 ether);

    return param;
  }

  function test_withdrawCollateral() public {
    MarketParams memory param = test_supplyCollateral();

    uint256 bnbBalanceBefore = user.balance;
    vm.startPrank(user);
    bnbProvider.withdrawCollateral(param, 1 ether, user, payable(user));

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 0);
    assertEq(user.balance, bnbBalanceBefore + 1 ether);
  }

  function test_withdrawCollateral_onBehalf() public {
    MarketParams memory param = test_supplyCollateral();
    vm.stopPrank();

    uint256 bnbBalanceBefore = user2.balance;
    vm.prank(user);
    ardentis.setAuthorization(user2, true);

    vm.startPrank(user2);
    bnbProvider.withdrawCollateral(param, 1 ether, user, payable(user2));

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 0);
    assertEq(user2.balance, bnbBalanceBefore + 1 ether);
  }

  function test_supplyCollateral_btcb() public returns (MarketParams memory) {
    deal(BTCB, user, 100 ether);

    MarketParams memory param = MarketParams({
      loanToken: WBNB,
      collateralToken: BTCB,
      oracle: multiOracle,
      irm: irm,
      lltv: lltv80
    });

    uint256 balanceBefore = IERC20(BTCB).balanceOf(user);
    uint256 ardentisBalanceBefore = IERC20(BTCB).balanceOf(ardentisProxy);
    vm.startPrank(user);
    vm.expectRevert();
    bnbProvider.supplyCollateral{ value: 1 ether }(param, user, "");
    IERC20(BTCB).approve(address(ardentis), 1 ether);
    ardentis.supplyCollateral(param, 1 ether, user, "");

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 1 ether);
    assertEq(IERC20(BTCB).balanceOf(ardentisProxy), ardentisBalanceBefore + 1 ether);
    assertEq(IERC20(BTCB).balanceOf(user), balanceBefore - 1 ether);

    return param;
  }

  function test_borrow() public returns (MarketParams memory) {
    MarketParams memory param = test_supplyCollateral_btcb();

    uint256 balanceBefore = user.balance;
    vm.startPrank(user);
    bnbProvider.borrow(param, 1 ether, 0, user, payable(user));

    uint256 assets = 1 ether;
    (
      uint128 totalSupplyAssets,
      uint128 totalSupplyShares,
      uint128 totalBorrowAssets,
      uint128 totalBorrowShares,
      uint128 lastUpdate,
      uint128 fee
    ) = ardentis.market(param.id());

    uint256 shares = assets.toSharesUp(totalBorrowAssets, totalBorrowShares);
    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, shares);
    assertEq(collateral, 1 ether);
    assertEq(user.balance, balanceBefore + assets);

    return param;
  }

  function test_borrow_onBehalf() public returns (MarketParams memory) {
    MarketParams memory param = test_supplyCollateral_btcb();
    vm.stopPrank();

    uint256 balanceBefore = user2.balance;
    vm.prank(user);
    ardentis.setAuthorization(user2, true);

    vm.startPrank(user2);
    bnbProvider.borrow(param, 1 ether, 0, user, payable(user2));

    uint256 assets = 1 ether;
    (
      uint128 totalSupplyAssets,
      uint128 totalSupplyShares,
      uint128 totalBorrowAssets,
      uint128 totalBorrowShares,
      uint128 lastUpdate,
      uint128 fee
    ) = ardentis.market(param.id());

    uint256 shares = assets.toSharesUp(totalBorrowAssets, totalBorrowShares);
    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, shares);
    assertEq(collateral, 1 ether);
    assertEq(user2.balance, balanceBefore + assets);

    return param;
  }

  function test_repay() public {
    deal(user, 100 ether);
    MarketParams memory param = test_borrow();

    skip(1 days);

    ardentis.accrueInterest(param);
    vm.startPrank(user);
    (uint256 supplySharesBefore, uint128 borrowSharesBefore, uint128 collateralBefore) = ardentis.position(
      param.id(),
      user
    );
    (, , uint128 totalBorrowAssets, uint128 totalBorrowShares, , ) = ardentis.market(param.id());
    uint256 assets = uint256(borrowSharesBefore).toAssetsUp(totalBorrowAssets, totalBorrowShares);
    uint256 balanceBefore = user.balance;
    vm.expectRevert("insufficient funds");
    bnbProvider.repay{ value: 0 }(param, 0, borrowSharesBefore, user, "");
    bnbProvider.repay{ value: assets + 100 }(param, 0, borrowSharesBefore, user, "");

    (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = ardentis.position(param.id(), user);
    assertEq(supplyShares, 0);
    assertEq(borrowShares, 0);
    assertEq(collateral, 1 ether);
    assertEq(user.balance, balanceBefore - assets);
  }

  function test_addVault() public {
    ArdentisVault newVaultImpl = new ArdentisVault(ardentisProxy, WBNB);
    address newVaultProxy = address(
      new ERC1967Proxy(
        address(newVaultImpl),
        abi.encodeWithSelector(newVaultImpl.initialize.selector, admin, manager, WBNB, "new vault", "new vault")
      )
    );
    vm.startPrank(manager);
    bnbProvider.addVault(newVaultProxy);
    vm.stopPrank();

    assertEq(bnbProvider.vaults(newVaultProxy), true, "add vault failed");
  }

  function test_removeVault() public {
    vm.startPrank(manager);
    bnbProvider.removeVault(ardentisVaultProxy);
    vm.stopPrank();

    assertEq(bnbProvider.vaults(ardentisVaultProxy), false, "remove vault failed");
  }

  function test_depositNotInVaults() public {
    deal(user, 100 ether);

    vm.startPrank(manager);
    bnbProvider.removeVault(ardentisVaultProxy);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(bytes("vault not added"));
    bnbProvider.deposit{ value: 1 ether }(ardentisVaultProxy, user);

    vm.expectRevert(bytes("vault not added"));
    bnbProvider.mint{ value: 1 ether }(ardentisVaultProxy, 1 ether, user);
    vm.stopPrank();
  }

  function test_withdrawNotInVaults() public {
    test_deposit();

    bnbProvider.deposit{ value: 1 ether }(ardentisVaultProxy, user);

    vm.startPrank(manager);
    bnbProvider.removeVault(ardentisVaultProxy);
    vm.stopPrank();

    vm.startPrank(user);
    vm.expectRevert(bytes("vault not added"));
    bnbProvider.withdraw(ardentisVaultProxy, 1 ether, payable(user), user);

    uint256 shares = ardentisVault.balanceOf(user);
    vm.expectRevert(bytes("vault not added"));
    bnbProvider.redeem(ardentisVaultProxy, shares, payable(user), user);
    vm.stopPrank();
  }

  function test_depositInVaults() public {
    deal(user, 100 ether);

    uint256 bnbBalanceBefore = user.balance;
    uint256 wbnbBalanceBefore = IERC20(WBNB).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = bnbProvider.deposit{ value: 1 ether }(ardentisVaultProxy, user);
    assertEq(shares, expectShares);

    assertEq(user.balance, bnbBalanceBefore - 1 ether);
    assertEq(ardentisVault.balanceOf(user), expectShares);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(IERC20(WBNB).balanceOf(ardentisVaultProxy), 0);
    assertEq(IERC20(WBNB).balanceOf(ardentisProxy), wbnbBalanceBefore + 1 ether);
  }

  function test_mintInVaults() public {
    deal(user, 100 ether);

    uint256 bnbBalanceBefore = user.balance;
    uint256 wbnbBalanceBefore = IERC20(WBNB).balanceOf(ardentisProxy);
    vm.startPrank(user);
    uint256 expectAsset = ardentisVault.previewMint(1 ether);
    uint256 assets = bnbProvider.mint{ value: expectAsset }(ardentisVaultProxy, 1 ether, user);

    assertEq(assets, expectAsset);
    assertEq(user.balance, bnbBalanceBefore - expectAsset);
    assertEq(ardentisVault.balanceOf(user), 1 ether);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(IERC20(WBNB).balanceOf(ardentisProxy), wbnbBalanceBefore + expectAsset);
  }

  function test_withdrawInVaults() public {
    test_depositInVaults();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 expectShares = ardentisVault.convertToShares(1 ether);
    uint256 shares = bnbProvider.withdraw(ardentisVaultProxy, 1 ether, payable(user), user);

    assertApproxEqAbs(shares, expectShares, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertEq(user.balance, balanceBefore + 1 ether);
    assertEq(ardentisVault.totalAssets(), totalAssets - 1 ether);
  }

  function test_redeemInVaults() public {
    test_depositInVaults();

    skip(1 days);

    vm.startPrank(user);
    uint256 balanceBefore = user.balance;
    uint256 sharesBefore = ardentisVault.balanceOf(user);
    uint256 totalAssets = ardentisVault.totalAssets();
    uint256 shares = ardentisVault.convertToShares(1 ether);
    uint256 assets = bnbProvider.redeem(ardentisVaultProxy, shares, payable(user), user);

    assertApproxEqAbs(assets, 1 ether, 1);
    assertEq(ardentisVault.balanceOf(user), sharesBefore - shares);
    assertEq(ardentisVault.balanceOf(address(bnbProvider)), 0);
    assertApproxEqAbs(user.balance, balanceBefore + 1 ether, 1);
    assertApproxEqAbs(ardentisVault.totalAssets(), totalAssets - 1 ether, 1);
  }

  function getImplementation(address _proxyAddress) public view returns (address) {
    bytes32 implSlot = vm.load(_proxyAddress, IMPLEMENTATION_SLOT);
    return address(uint160(uint256(implSlot)));
  }
}
