// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IWBNB } from "./interfaces/IWBNB.sol";
import { IProvider } from "./interfaces/IProvider.sol";

import { MarketParamsLib } from "../ardentis/libraries/MarketParamsLib.sol";
import { SharesMathLib } from "../ardentis/libraries/SharesMathLib.sol";
import { IArdentisVault } from "../ardentis-vault/interfaces/IArdentisVault.sol";
import { Id, IArdentis, MarketParams, Market } from "../ardentis/interfaces/IArdentis.sol";
import { ErrorsLib } from "../ardentis/libraries/ErrorsLib.sol";
import { UtilsLib } from "../ardentis/libraries/UtilsLib.sol";

/// @title BNB Provider for Ardentis Lending
/// @author Ardentis
/// @notice This contract allows users to interact with the Ardentis protocol using native BNB.
/// @dev
/// - Handles interactions with the WBNB vault for deposit, mint, withdraw, and redeem operations.
/// - Integrates with the Ardentis core contract to support borrowing, repayment, and collateral management using BNB.
contract BNBProvider is UUPSUpgradeable, AccessControlEnumerableUpgradeable, IProvider {
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;

  /* IMMUTABLES */

  IArdentis public immutable ARDENTIS;
  IArdentisVault public immutable ARDENTIS_VAULT;
  address public immutable TOKEN;

  mapping(address => bool) public vaults;

  bytes32 public constant MANAGER = keccak256("MANAGER");

  modifier onlyArdentis() {
    require(msg.sender == address(ARDENTIS), "not ardentis");
    _;
  }

  /* CONSTRUCTOR */

  /// @custom:oz-upgrades-unsafe-allow constructor
  /// @param ardentis The address of the Ardentis contract.
  /// @param ardentisVault The address of the WBNB Ardentis Vault contract.
  /// @param wbnb The address of the WBNB contract.
  constructor(address ardentis, address ardentisVault, address wbnb) {
    require(ardentis != address(0), ErrorsLib.ZERO_ADDRESS);
    require(ardentisVault != address(0), ErrorsLib.ZERO_ADDRESS);
    require(ardentis == address(IArdentisVault(ardentisVault).ARDENTIS()), ErrorsLib.NOT_SET);
    require(wbnb != address(0), ErrorsLib.ZERO_ADDRESS);
    require(wbnb == IArdentisVault(ardentisVault).asset(), "asset mismatch");

    ARDENTIS = IArdentis(ardentis);
    ARDENTIS_VAULT = IArdentisVault(ardentisVault);
    TOKEN = wbnb;

    _disableInitializers();
  }

  /// @param admin The admin of the contract.
  /// @param manager The manager of the contract.
  function initialize(address admin, address manager) public initializer {
    require(admin != address(0), ErrorsLib.ZERO_ADDRESS);
    require(manager != address(0), ErrorsLib.ZERO_ADDRESS);

    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(MANAGER, manager);
  }

  /// @dev Deposit BNB and receive shares.
  /// @param receiver The address to receive the shares.
  /// @return shares The number of shares received.
  function deposit(address receiver) external payable returns (uint256 shares) {
    return deposit(address(ARDENTIS_VAULT), receiver);
  }

  /// @dev Deposit BNB and receive shares by specifying the amount of shares.
  /// @param shares The amount of shares to mint.
  /// @param receiver The address to receive the shares.
  function mint(uint256 shares, address receiver) external payable returns (uint256 assets) {
    return mint(address(ARDENTIS_VAULT), shares, receiver);
  }

  /// @dev Withdraw shares from owner and send BNB to receiver by specifying the amount of assets.
  /// @param assets The amount of assets to withdraw.
  /// @param receiver The address to receive the assets.
  /// @param owner The address of the owner of the shares.
  function withdraw(uint256 assets, address payable receiver, address owner) external returns (uint256 shares) {
    return withdraw(address(ARDENTIS_VAULT), assets, receiver, owner);
  }

  /// @dev Withdraw shares from owner and send BNB to receiver by specifying the amount of shares.
  /// @param shares The amount of shares to withdraw.
  /// @param receiver The address to receive the assets.
  /// @param owner The address of the owner of the shares.
  function redeem(uint256 shares, address payable receiver, address owner) external returns (uint256 assets) {
    return redeem(address(ARDENTIS_VAULT), shares, receiver, owner);
  }

  /// @dev Deposit BNB and receive shares.
  /// @param vault The address of the Ardentis vault to deposit into.
  /// @param receiver The address to receive the shares.
  /// @return shares The number of shares received.
  function deposit(address vault, address receiver) public payable returns (uint256 shares) {
    require(vaults[vault], "vault not added");
    uint256 assets = msg.value;
    require(assets > 0, ErrorsLib.ZERO_ASSETS);

    IWBNB(TOKEN).deposit{ value: assets }();
    require(IWBNB(TOKEN).approve(vault, assets));

    shares = IArdentisVault(vault).deposit(assets, receiver);
  }

  /// @dev Deposit BNB and receive shares by specifying the amount of shares.
  /// @param vault The address of the Ardentis vault to deposit into.
  /// @param shares The amount of shares to mint.
  /// @param receiver The address to receive the shares.
  function mint(address vault, uint256 shares, address receiver) public payable returns (uint256 assets) {
    require(vaults[vault], "vault not added");
    require(shares > 0, ErrorsLib.ZERO_ASSETS);
    uint256 previewAssets = IArdentisVault(vault).previewMint(shares); // ceiling rounding
    require(msg.value >= previewAssets, "invalid BNB amount");

    IWBNB(TOKEN).deposit{ value: previewAssets }();
    require(IWBNB(TOKEN).approve(vault, previewAssets));
    assets = IArdentisVault(vault).mint(shares, receiver);

    if (msg.value > assets) {
      (bool success, ) = msg.sender.call{ value: msg.value - assets }("");
      require(success, "transfer failed");
    }
  }

  /// @dev Withdraw shares from owner and send BNB to receiver by specifying the amount of assets.
  /// @param vault The address of the Ardentis vault to withdraw from.
  /// @param assets The amount of assets to withdraw.
  /// @param receiver The address to receive the assets.
  /// @param owner The address of the owner of the shares.
  function withdraw(
    address vault,
    uint256 assets,
    address payable receiver,
    address owner
  ) public returns (uint256 shares) {
    require(vaults[vault], "vault not added");
    require(assets > 0, ErrorsLib.ZERO_ASSETS);
    require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

    // 1. withdraw WBNB from ardentis vault
    shares = IArdentisVault(vault).withdrawFor(assets, owner, msg.sender);

    // 2. unwrap WBNB
    IWBNB(TOKEN).withdraw(assets);

    // 3. transfer WBNB to receiver
    (bool success, ) = receiver.call{ value: assets }("");
    require(success, "transfer failed");
  }

  /// @dev Withdraw shares from owner and send BNB to receiver by specifying the amount of shares.
  /// @param vault The address of the Ardentis vault to withdraw from.
  /// @param shares The amount of shares to withdraw.
  /// @param receiver The address to receive the assets.
  /// @param owner The address of the owner of the shares.
  function redeem(
    address vault,
    uint256 shares,
    address payable receiver,
    address owner
  ) public returns (uint256 assets) {
    require(vaults[vault], "vault not added");
    require(shares > 0, ErrorsLib.ZERO_ASSETS);
    require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

    // 1. redeem WBNB from ardentis vault
    assets = IArdentisVault(vault).redeemFor(shares, owner, msg.sender);

    // 2. unwrap WBNB
    IWBNB(TOKEN).withdraw(assets);

    // 3. transfer BNB to receiver
    (bool success, ) = receiver.call{ value: assets }("");
    require(success, "transfer failed");
  }

  /// @dev Borrow BNB from onBehalf's position and send BNB to receiver
  /// @param marketParams The market parameters.
  /// @param assets The amount of assets to borrow.
  /// @param shares The amount of shares to borrow.
  /// @param onBehalf The address of the position owner to borrow from.
  /// @param receiver The address to receive the BNB.
  function borrow(
    MarketParams calldata marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    address payable receiver
  ) external returns (uint256 _assets, uint256 _shares) {
    // No need to verify assets and shares, as they are already verified in the Ardentis contract.
    require(marketParams.loanToken == TOKEN, "invalid loan token");
    require(isSenderAuthorized(msg.sender, onBehalf), ErrorsLib.UNAUTHORIZED);
    require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

    // 1. borrow WBNB from ardentis
    (_assets, _shares) = ARDENTIS.borrow(marketParams, assets, shares, onBehalf, address(this));

    // 2. unwrap WBNB
    IWBNB(TOKEN).withdraw(_assets);

    // 3. transfer BNB to receiver
    (bool success, ) = receiver.call{ value: _assets }("");
    require(success, "transfer failed");
  }

  /// @dev Repay BNB to onBehalf's position
  /// @param marketParams The market parameters.
  /// @param assets The amount of assets to repay.
  /// @param shares The amount of shares to repay.
  /// @param onBehalf The address of the position owner to repay.
  /// @param data The data to pass to the Ardentis contract.
  function repay(
    MarketParams calldata marketParams,
    uint256 assets,
    uint256 shares,
    address onBehalf,
    bytes calldata data
  ) external payable returns (uint256 _assets, uint256 _shares) {
    require(UtilsLib.exactlyOneZero(assets, shares), ErrorsLib.INCONSISTENT_INPUT);
    require(marketParams.loanToken == TOKEN, "invalid loan token");
    require(msg.value >= assets, "invalid BNB amount");

    // accrue interest on the market and then calculate `wrapAmount`
    ARDENTIS.accrueInterest(marketParams);

    uint256 wrapAmount = assets;
    if (wrapAmount == 0) {
      // If assets is 0, we need to wrap the shares amount
      require(shares > 0, ErrorsLib.ZERO_ASSETS);
      Market memory market = ARDENTIS.market(marketParams.id());
      wrapAmount = shares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
      require(msg.value >= wrapAmount, "insufficient funds");
    }

    // 1. wrap BNB to WBNB
    IWBNB(TOKEN).deposit{ value: wrapAmount }();
    // 2. approve ardentis to transfer WBNB
    require(IWBNB(TOKEN).approve(address(ARDENTIS), wrapAmount));
    // 3. repay WBNB to ardentis
    (_assets, _shares) = ARDENTIS.repay(marketParams, assets, shares, onBehalf, data);

    // 4. return excess BNB to sender
    if (msg.value > wrapAmount) {
      (bool success, ) = msg.sender.call{ value: msg.value - wrapAmount }("");
      require(success, "transfer failed");
    }
  }

  /// @dev Supply collateral to onBehalf's position
  /// @param marketParams The market parameters.
  /// @param onBehalf The address of the position owner to supply collateral to.
  /// @param data The data to pass to the Ardentis contract.
  function supplyCollateral(
    MarketParams calldata marketParams,
    address onBehalf,
    bytes calldata data
  ) external payable {
    uint256 assets = msg.value;
    require(assets > 0, ErrorsLib.ZERO_ASSETS);
    require(marketParams.collateralToken == TOKEN, "invalid collateral token");

    // 1. deposit WBNB
    IWBNB(TOKEN).deposit{ value: assets }();
    // 2. approve ardentis to transfer WBNB
    require(IWBNB(TOKEN).approve(address(ARDENTIS), assets));
    // 3. supply collateral to ardentis
    ARDENTIS.supplyCollateral(marketParams, assets, onBehalf, data);
  }

  /// @dev Withdraw collateral from onBehalf's position
  /// @param marketParams The market parameters.
  /// @param assets The amount of assets to withdraw.
  /// @param onBehalf The address of the position owner to withdraw collateral from. msg.sender must be authorized to manage onBehalf's position.
  /// @param receiver The address to receive the assets.
  function withdrawCollateral(
    MarketParams calldata marketParams,
    uint256 assets,
    address onBehalf,
    address payable receiver
  ) external {
    require(marketParams.collateralToken == TOKEN, "invalid collateral token");
    require(isSenderAuthorized(msg.sender, onBehalf), ErrorsLib.UNAUTHORIZED);
    require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

    // 1. withdraw WBNB from ardentis by specifying the amount
    ARDENTIS.withdrawCollateral(marketParams, assets, onBehalf, address(this));

    // 2. unwrap WBNB
    IWBNB(TOKEN).withdraw(assets);

    // 3. transfer BNB to receiver
    (bool success, ) = receiver.call{ value: assets }("");
    require(success, "transfer failed");
  }

  /// @dev empty function to allow ardentis to do liquidation
  /// @dev may support burn clisBnb in the future (mint clisBnb by providing BNB)
  function liquidate(Id id, address borrower) external onlyArdentis {}

  /// @dev Add a Ardentis vault to the provider.
  function addVault(address vault) external {
    require(hasRole(MANAGER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), ErrorsLib.UNAUTHORIZED);
    require(vault != address(0), ErrorsLib.ZERO_ADDRESS);
    require(!vaults[vault], "vault already added");
    require(address(IArdentisVault(vault).ARDENTIS()) == address(ARDENTIS), "invalid ardentis vault");
    require(IArdentisVault(vault).asset() == TOKEN, "invalid asset");
    vaults[vault] = true;
  }

  /// @dev Remove a Ardentis vault from the provider.
  function removeVault(address vault) external {
    require(hasRole(MANAGER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), ErrorsLib.UNAUTHORIZED);
    require(vaults[vault], "vault not added");
    delete vaults[vault];
  }

  /// @dev Returns whether the sender is authorized to manage `onBehalf`'s positions.
  /// @param sender The address of the sender to check.
  /// @param onBehalf The address of the position owner.
  function isSenderAuthorized(address sender, address onBehalf) public view returns (bool) {
    return sender == onBehalf || ARDENTIS.isAuthorized(onBehalf, sender);
  }

  receive() external payable {}

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
