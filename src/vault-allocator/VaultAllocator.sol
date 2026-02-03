// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import { FlowCaps, FlowCapsConfig, Withdrawal, MAX_SETTABLE_FLOW_CAP, IVaultAllocatorStaticTyping, IVaultAllocatorBase } from "./interfaces/IVaultAllocator.sol";
import { Id, IArdentis, IArdentisVault, MarketAllocation, MarketParams } from "ardentis-vault/interfaces/IArdentisVault.sol";
import { Market } from "ardentis/interfaces/IArdentis.sol";

import { ErrorsLib } from "./libraries/ErrorsLib.sol";
import { EventsLib } from "./libraries/EventsLib.sol";
import { UtilsLib } from "ardentis/libraries/UtilsLib.sol";
import { MarketParamsLib } from "ardentis/libraries/MarketParamsLib.sol";
import { ArdentisBalancesLib } from "ardentis/libraries/periphery/ArdentisBalancesLib.sol";

/// @title VaultAllocator
/// @author Ardentis
/// @notice Publicly callable allocator for ArdentisVault vaults.
contract VaultAllocator is UUPSUpgradeable, AccessControlEnumerableUpgradeable, IVaultAllocatorStaticTyping {
  using ArdentisBalancesLib for IArdentis;
  using MarketParamsLib for MarketParams;
  using UtilsLib for uint256;

  /* CONSTANTS */

  /// @inheritdoc IVaultAllocatorBase
  IArdentis public immutable ARDENTIS;

  /* STORAGE */

  /// @inheritdoc IVaultAllocatorBase
  mapping(address => address) public admin;
  /// @inheritdoc IVaultAllocatorBase
  mapping(address => uint256) public fee;
  /// @inheritdoc IVaultAllocatorBase
  mapping(address => uint256) public accruedFee;
  /// @inheritdoc IVaultAllocatorStaticTyping
  mapping(address => mapping(Id => FlowCaps)) public flowCaps;

  bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role

  /* MODIFIER */

  /// @dev Reverts if the caller is not the admin nor the owner of this vault.
  modifier onlyAdminOrVaultOwner(address vault) {
    if (msg.sender != admin[vault] && !IArdentisVault(vault).hasRole(MANAGER, msg.sender)) {
      revert ErrorsLib.NotAdminNorVaultOwner();
    }
    _;
  }

  /* CONSTRUCTOR */

  /// @custom:oz-upgrades-unsafe-allow constructor
  /// @param ardentis The address of the Ardentis contract.
  constructor(address ardentis) {
    require(ardentis != address(0), ErrorsLib.ZERO_ADDRESS);
    _disableInitializers();
    ARDENTIS = IArdentis(ardentis);
  }

  /// @dev Initializes the contract.
  /// @param _admin The new admin of the contract.
  function initialize(address _admin) public initializer {
    require(_admin != address(0), ErrorsLib.ZERO_ADDRESS);

    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  /* ADMIN OR VAULT OWNER ONLY */

  /// @inheritdoc IVaultAllocatorBase
  function setAdmin(address vault, address newAdmin) external onlyAdminOrVaultOwner(vault) {
    if (admin[vault] == newAdmin) revert ErrorsLib.AlreadySet();
    admin[vault] = newAdmin;
    emit EventsLib.SetAdmin(msg.sender, vault, newAdmin);
  }

  /// @inheritdoc IVaultAllocatorBase
  function setFee(address vault, uint256 newFee) external onlyAdminOrVaultOwner(vault) {
    if (fee[vault] == newFee) revert ErrorsLib.AlreadySet();
    fee[vault] = newFee;
    emit EventsLib.SetFee(msg.sender, vault, newFee);
  }

  /// @inheritdoc IVaultAllocatorBase
  function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external onlyAdminOrVaultOwner(vault) {
    for (uint256 i = 0; i < config.length; i++) {
      Id id = config[i].id;
      if (!IArdentisVault(vault).config(id).enabled && (config[i].caps.maxIn > 0 || config[i].caps.maxOut > 0)) {
        revert ErrorsLib.MarketNotEnabled(id);
      }
      if (config[i].caps.maxIn > MAX_SETTABLE_FLOW_CAP || config[i].caps.maxOut > MAX_SETTABLE_FLOW_CAP) {
        revert ErrorsLib.MaxSettableFlowCapExceeded();
      }
      flowCaps[vault][id] = config[i].caps;
    }

    emit EventsLib.SetFlowCaps(msg.sender, vault, config);
  }

  /// @inheritdoc IVaultAllocatorBase
  function transferFee(address vault, address payable feeRecipient) external onlyAdminOrVaultOwner(vault) {
    uint256 claimed = accruedFee[vault];
    accruedFee[vault] = 0;
    (bool success, ) = feeRecipient.call{ value: claimed }("");
    require(success, "Transfer failed");
    emit EventsLib.TransferFee(msg.sender, vault, claimed, feeRecipient);
  }

  /// @inheritdoc IVaultAllocatorBase
  function reallocateTo(
    address vault,
    Withdrawal[] calldata withdrawals,
    MarketParams calldata supplyMarketParams
  ) external payable onlyAdminOrVaultOwner(vault) {
    if (msg.value != fee[vault]) revert ErrorsLib.IncorrectFee();
    if (msg.value > 0) accruedFee[vault] += msg.value;

    if (withdrawals.length == 0) revert ErrorsLib.EmptyWithdrawals();

    Id supplyMarketId = supplyMarketParams.id();
    if (!IArdentisVault(vault).config(supplyMarketId).enabled) revert ErrorsLib.MarketNotEnabled(supplyMarketId);

    MarketAllocation[] memory allocations = new MarketAllocation[](withdrawals.length + 1);
    uint128 totalWithdrawn;

    Id id;
    Id prevId;
    for (uint256 i = 0; i < withdrawals.length; i++) {
      prevId = id;
      id = withdrawals[i].marketParams.id();
      if (!IArdentisVault(vault).config(id).enabled) revert ErrorsLib.MarketNotEnabled(id);
      uint128 withdrawnAssets = withdrawals[i].amount;
      if (withdrawnAssets == 0) revert ErrorsLib.WithdrawZero(id);

      if (Id.unwrap(id) <= Id.unwrap(prevId)) revert ErrorsLib.InconsistentWithdrawals();
      if (Id.unwrap(id) == Id.unwrap(supplyMarketId)) revert ErrorsLib.DepositMarketInWithdrawals();

      ARDENTIS.accrueInterest(withdrawals[i].marketParams);
      uint256 assets = ARDENTIS.expectedSupplyAssets(withdrawals[i].marketParams, address(vault));

      if (flowCaps[vault][id].maxOut < withdrawnAssets) revert ErrorsLib.MaxOutflowExceeded(id);
      if (assets < withdrawnAssets) revert ErrorsLib.NotEnoughSupply(id);

      flowCaps[vault][id].maxIn += withdrawnAssets;
      flowCaps[vault][id].maxOut -= withdrawnAssets;
      allocations[i].marketParams = withdrawals[i].marketParams;
      allocations[i].assets = assets - withdrawnAssets;

      totalWithdrawn += withdrawnAssets;

      emit EventsLib.PublicWithdrawal(msg.sender, vault, id, withdrawnAssets);
    }

    if (flowCaps[vault][supplyMarketId].maxIn < totalWithdrawn) revert ErrorsLib.MaxInflowExceeded(supplyMarketId);

    flowCaps[vault][supplyMarketId].maxIn -= totalWithdrawn;
    flowCaps[vault][supplyMarketId].maxOut += totalWithdrawn;
    allocations[withdrawals.length].marketParams = supplyMarketParams;
    allocations[withdrawals.length].assets = type(uint256).max;

    IArdentisVault(vault).reallocate(allocations);

    emit EventsLib.PublicReallocateTo(msg.sender, vault, supplyMarketId, totalWithdrawn);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
