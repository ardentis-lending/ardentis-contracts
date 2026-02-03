// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { IWETH } from "./interfaces/IWETH.sol";
import { IProvider } from "./interfaces/IProvider.sol";

import { MarketParamsLib } from "../ardentis/libraries/MarketParamsLib.sol";
import { SharesMathLib } from "../ardentis/libraries/SharesMathLib.sol";
import { IArdentisVault } from "../ardentis-vault/interfaces/IArdentisVault.sol";
import { Id, IArdentis, MarketParams, Market } from "../ardentis/interfaces/IArdentis.sol";
import { ErrorsLib } from "../ardentis/libraries/ErrorsLib.sol";
import { UtilsLib } from "../ardentis/libraries/UtilsLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @title ETH Provider for Ardentis Lending
/// @author Ardentis
/// @notice This contract allows users to interact with the Ardentis protocol using Ether.
/// @dev
/// - Handles interactions with the WETH vault for deposit, mint, withdraw, and redeem operations.
/// - Integrates with the Ardentis core contract to support borrowing, repayment, and collateral management using Ether.
contract ETHProvider is UUPSUpgradeable, AccessControlEnumerableUpgradeable, IProvider {
  using MarketParamsLib for MarketParams;
  using SharesMathLib for uint256;

  /* IMMUTABLES */

  IArdentis public immutable ARDENTIS;
  address public immutable TOKEN;

  mapping(address => bool) public vaults;

  bytes32 public constant MANAGER = keccak256("MANAGER");

  event AddVault(address indexed caller, address indexed vault);
  event RemoveVault(address indexed caller, address indexed vault);
  event Rescue(address indexed caller, address indexed token, address indexed to, uint256 amount);

  modifier onlyArdentis() {
    require(msg.sender == address(ARDENTIS), "not ardentis");
    _;
  }

  /* CONSTRUCTOR */

  /// @custom:oz-upgrades-unsafe-allow constructor
  /// @param ardentis The address of the Ardentis contract.
  /// @param weth The address of the WETH contract.
  constructor(address ardentis, address weth) {
    require(ardentis != address(0), ErrorsLib.ZERO_ADDRESS);
    require(weth != address(0), ErrorsLib.ZERO_ADDRESS);

    ARDENTIS = IArdentis(ardentis);
    TOKEN = weth;

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

  /// @dev Deposit ETH and receive shares.
  /// @param vault The address of the Ardentis vault to deposit into.
  /// @param receiver The address to receive the shares.
  /// @return shares The number of shares received.
  function deposit(address vault, address receiver) public payable returns (uint256 shares) {
    require(vaults[vault], "vault not added");
    uint256 assets = msg.value;
    require(assets > 0, ErrorsLib.ZERO_ASSETS);

    IWETH(TOKEN).deposit{ value: assets }();
    require(IWETH(TOKEN).approve(vault, assets));

    shares = IArdentisVault(vault).deposit(assets, receiver);
  }

  /// @dev Deposit ETH and receive shares by specifying the amount of shares.
  /// @param vault The address of the Ardentis vault to deposit into.
  /// @param shares The amount of shares to mint.
  /// @param receiver The address to receive the shares.
  /// @return assets The amount of assets equivalent to the minted shares.
  function mint(address vault, uint256 shares, address receiver) public payable returns (uint256 assets) {
    require(vaults[vault], "vault not added");
    require(shares > 0, ErrorsLib.ZERO_ASSETS);
    uint256 previewAssets = IArdentisVault(vault).previewMint(shares); // ceiling rounding
    require(msg.value >= previewAssets, "invalid ETH amount");

    IWETH(TOKEN).deposit{ value: previewAssets }();
    require(IWETH(TOKEN).approve(vault, previewAssets));
    assets = IArdentisVault(vault).mint(shares, receiver);

    if (msg.value > assets) {
      (bool success, ) = msg.sender.call{ value: msg.value - assets }("");
      require(success, "transfer failed");
    }
  }

  /// @dev Withdraw shares from owner and send ETH to receiver by specifying the amount of assets.
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

    // 1. withdraw WETH from ardentis vault
    shares = IArdentisVault(vault).withdrawFor(assets, owner, msg.sender);

    // 2. unwrap WETH
    IWETH(TOKEN).withdraw(assets);

    // 3. transfer ether to receiver
    (bool success, ) = receiver.call{ value: assets }("");
    require(success, "transfer failed");
  }

  /// @dev Withdraw shares from owner and send ETH to receiver by specifying the amount of shares.
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

    // 1. redeem WETH from ardentis vault
    assets = IArdentisVault(vault).redeemFor(shares, owner, msg.sender);

    // 2. unwrap WETH
    IWETH(TOKEN).withdraw(assets);

    // 3. transfer ETH to receiver
    (bool success, ) = receiver.call{ value: assets }("");
    require(success, "transfer failed");
  }

  /// @dev Borrow ETH from onBehalf's position and send ETH to receiver
  /// @param marketParams The market parameters.
  /// @param assets The amount of assets to borrow.
  /// @param shares The amount of shares to borrow.
  /// @param onBehalf The address of the position owner to borrow from.
  /// @param receiver The address to receive the ETH.
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

    // 1. borrow WETH from ardentis
    (_assets, _shares) = ARDENTIS.borrow(marketParams, assets, shares, onBehalf, address(this));

    // 2. unwrap WETH
    IWETH(TOKEN).withdraw(_assets);

    // 3. transfer ETH to receiver
    (bool success, ) = receiver.call{ value: _assets }("");
    require(success, "transfer failed");
  }

  /// @dev Repay ETH to onBehalf's position
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
    require(msg.value >= assets, "invalid ETH amount");
    require(data.length == 0, "callback not supported");

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

    // 1. wrap ETH to WETH
    IWETH(TOKEN).deposit{ value: wrapAmount }();
    // 2. approve ardentis to transfer WETH
    require(IWETH(TOKEN).approve(address(ARDENTIS), wrapAmount));
    // 3. repay WETH to ardentis
    (_assets, _shares) = ARDENTIS.repay(marketParams, assets, shares, onBehalf, data);

    // 4. return excess ETH to sender
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
    require(data.length == 0, "callback not supported");

    // 1. deposit WETH
    IWETH(TOKEN).deposit{ value: assets }();
    // 2. approve ardentis to transfer WETH
    require(IWETH(TOKEN).approve(address(ARDENTIS), assets));
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

    // 1. withdraw WETH from ardentis by specifying the amount
    ARDENTIS.withdrawCollateral(marketParams, assets, onBehalf, address(this));

    // 2. unwrap WETH
    IWETH(TOKEN).withdraw(assets);

    // 3. transfer ETH to receiver
    (bool success, ) = receiver.call{ value: assets }("");
    require(success, "transfer failed");
  }

  /// @dev empty function to allow ardentis to do liquidation
  function liquidate(Id id, address borrower) external onlyArdentis {}

  /// @dev Add a Ardentis vault to the provider.
  function addVault(address vault) external {
    require(hasRole(MANAGER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), ErrorsLib.UNAUTHORIZED);
    require(vault != address(0), ErrorsLib.ZERO_ADDRESS);
    require(!vaults[vault], "vault already added");
    require(address(IArdentisVault(vault).ARDENTIS()) == address(ARDENTIS), "invalid ardentis vault");
    require(IArdentisVault(vault).asset() == TOKEN, "invalid asset");
    vaults[vault] = true;
    emit AddVault(msg.sender, vault);
  }

  /// @dev Remove a Ardentis vault from the provider.
  function removeVault(address vault) external {
    require(hasRole(MANAGER, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), ErrorsLib.UNAUTHORIZED);
    require(vaults[vault], "vault not added");
    delete vaults[vault];
    emit RemoveVault(msg.sender, vault);
  }

  /// @dev Returns whether the sender is authorized to manage `onBehalf`'s positions.
  /// @param sender The address of the sender to check.
  /// @param onBehalf The address of the position owner.
  function isSenderAuthorized(address sender, address onBehalf) public view returns (bool) {
    return sender == onBehalf || ARDENTIS.isAuthorized(onBehalf, sender);
  }

  /// @dev Rescue native ETH or ERC20 tokens stuck in this contract.
  function rescue(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(to != address(0), ErrorsLib.ZERO_ADDRESS);

    if (token == address(0)) {
      uint256 balanceEth = address(this).balance;
      uint256 rescueAmountEth = amount == 0 ? balanceEth : amount;
      require(rescueAmountEth != 0, ErrorsLib.ZERO_ASSETS);
      require(rescueAmountEth <= balanceEth, ErrorsLib.INSUFFICIENT_LIQUIDITY);
      SafeTransferLib.safeTransferETH(to, rescueAmountEth);
      emit Rescue(msg.sender, address(0), to, rescueAmountEth);
      return;
    }

    require(token != TOKEN, "invalid asset");
    uint256 balanceToken = SafeTransferLib.balanceOf(token, address(this));
    uint256 rescueAmountToken = amount == 0 ? balanceToken : amount;
    require(rescueAmountToken != 0, ErrorsLib.ZERO_ASSETS);
    require(rescueAmountToken <= balanceToken, ErrorsLib.INSUFFICIENT_LIQUIDITY);
    SafeTransferLib.safeTransfer(token, to, rescueAmountToken);
    emit Rescue(msg.sender, token, to, rescueAmountToken);
  }

  receive() external payable {}

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
