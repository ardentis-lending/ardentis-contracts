// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ArdentisBalancesLib } from "ardentis/libraries/periphery/ArdentisBalancesLib.sol";
import { IArdentis, MarketParams, Id } from "ardentis/interfaces/IArdentis.sol";
import { IrmMock } from "ardentis/mocks/IrmMock.sol";
import { ERC20Mock } from "ardentis/mocks/ERC20Mock.sol";
import { OracleMock } from "ardentis/mocks/OracleMock.sol";
import { Ardentis } from "ardentis/Ardentis.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";
import { ArdentisVault } from "ardentis-vault/ArdentisVault.sol";
import { IArdentisVault } from "ardentis-vault/interfaces/IArdentisVault.sol";
import { ErrorsLib } from "ardentis-vault/libraries/ErrorsLib.sol";

contract ArdentisVaultAuditTest is Test {
  using ArdentisBalancesLib for IArdentis;
  using MarketParamsLib for MarketParams;

  address internal SUPPLIER;
  address internal BORROWER;
  address internal REPAYER;
  address internal ONBEHALF;
  address internal RECEIVER;
  address internal LIQUIDATOR;
  address internal OWNER;
  address internal FEE_RECIPIENT;
  address internal DEFAULT_ADMIN;

  IArdentis internal ardentis;
  ERC20Mock internal loanToken;
  ERC20Mock internal collateralToken;
  OracleMock internal oracle;
  IrmMock internal irm;
  IArdentisVault vault;

  MarketParams internal marketParams;
  Id internal id;

  uint256 internal constant DEFAULT_PRICE = 1e8;
  uint256 internal constant MIN_LOAN_VALUE = 15 * 1e8;
  uint256 internal constant DEFAULT_TEST_LLTV = 0.8 ether;
  bytes32 public constant CURATOR_ROLE = keccak256("CURATOR"); // manager role
  bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR"); // manager role

  function setUp() public {
    SUPPLIER = makeAddr("Supplier");
    BORROWER = makeAddr("Borrower");
    REPAYER = makeAddr("Repayer");
    ONBEHALF = makeAddr("OnBehalf");
    RECEIVER = makeAddr("Receiver");
    LIQUIDATOR = makeAddr("Liquidator");
    OWNER = makeAddr("Owner");
    FEE_RECIPIENT = makeAddr("FeeRecipient");
    oracle = new OracleMock();

    ardentis = newArdentis(OWNER, OWNER, OWNER, MIN_LOAN_VALUE);

    loanToken = new ERC20Mock();
    vm.label(address(loanToken), "LoanToken");

    collateralToken = new ERC20Mock();
    vm.label(address(collateralToken), "CollateralToken");

    oracle.setPrice(address(collateralToken), DEFAULT_PRICE);
    oracle.setPrice(address(loanToken), DEFAULT_PRICE);

    irm = new IrmMock();

    marketParams = MarketParams({
      loanToken: address(loanToken),
      collateralToken: address(collateralToken),
      oracle: address(oracle),
      irm: address(irm),
      lltv: DEFAULT_TEST_LLTV
    });

    id = marketParams.id();

    vm.startPrank(OWNER);
    ardentis.enableIrm(address(irm));
    ardentis.enableLltv(DEFAULT_TEST_LLTV);

    ardentis.createMarket(marketParams);
    vm.stopPrank();

    Id[] memory supplyQueue = new Id[](1);
    supplyQueue[0] = id;
    vault = newArdentisVault(OWNER, OWNER, address(ardentis), address(loanToken), "Ardentis Vault", "MVLT");
    vm.startPrank(OWNER);
    vault.grantRole(CURATOR_ROLE, OWNER);
    vault.grantRole(ALLOCATOR_ROLE, OWNER);
    vault.setCap(marketParams, type(uint128).max);
    vault.setSupplyQueue(supplyQueue);
    vm.stopPrank();

    vm.startPrank(SUPPLIER);
    loanToken.approve(address(ardentis), type(uint256).max);
    collateralToken.approve(address(ardentis), type(uint256).max);
    loanToken.approve(address(vault), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(BORROWER);
    loanToken.approve(address(ardentis), type(uint256).max);
    collateralToken.approve(address(ardentis), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(REPAYER);
    loanToken.approve(address(ardentis), type(uint256).max);
    collateralToken.approve(address(ardentis), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(LIQUIDATOR);
    loanToken.approve(address(ardentis), type(uint256).max);
    collateralToken.approve(address(ardentis), type(uint256).max);
    vm.stopPrank();

    vm.startPrank(ONBEHALF);
    loanToken.approve(address(ardentis), type(uint256).max);
    collateralToken.approve(address(ardentis), type(uint256).max);
    ardentis.setAuthorization(BORROWER, true);
    vm.stopPrank();
  }

  function newArdentis(
    address admin,
    address manager,
    address pauser,
    uint256 minLoanValue
  ) internal returns (IArdentis) {
    Ardentis ardentisImpl = new Ardentis();

    ERC1967Proxy ardentisProxy = new ERC1967Proxy(
      address(ardentisImpl),
      abi.encodeWithSelector(ardentisImpl.initialize.selector, admin, manager, pauser, minLoanValue)
    );

    return IArdentis(address(ardentisProxy));
  }

  function test_supplyVaultLessThanMinLoanValue() public {
    loanToken.setBalance(SUPPLIER, 100 ether);

    vm.startPrank(SUPPLIER);
    vm.expectRevert(abi.encodeWithSelector(ErrorsLib.AllCapsReached.selector));
    vault.deposit(MIN_LOAN_VALUE - 1, SUPPLIER);
    vm.stopPrank();
  }

  function newArdentisVault(
    address admin,
    address manager,
    address _ardentis,
    address _asset,
    string memory _name,
    string memory _symbol
  ) internal returns (IArdentisVault) {
    ArdentisVault ardentisVaultImpl = new ArdentisVault(_ardentis, _asset);
    ERC1967Proxy ardentisVaultProxy = new ERC1967Proxy(
      address(ardentisVaultImpl),
      abi.encodeWithSelector(ardentisVaultImpl.initialize.selector, admin, manager, _asset, _name, _symbol)
    );

    return IArdentisVault(address(ardentisVaultProxy));
  }
}
