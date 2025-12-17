// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IArdentisVaultFactory } from "./interfaces/IArdentisVaultFactory.sol";

import { EventsLib } from "./libraries/EventsLib.sol";
import { ErrorsLib } from "./libraries/ErrorsLib.sol";

/// @title ArdentisVaultFactoryInternal
/// @notice This contract allows to create ArdentisVault, and to index them easily.
contract ArdentisVaultFactoryInternal is UUPSUpgradeable, AccessControlEnumerableUpgradeable, IArdentisVaultFactory {
  /* IMMUTABLES */

  /// @inheritdoc IArdentisVaultFactory
  address public immutable ARDENTIS;

  address public constant ARDENTIS_VAULT_IMPL_18 = 0x9e26642152dF26a95E2e188dDa560d340E5E564C;

  /* STORAGE */

  /// @inheritdoc IArdentisVaultFactory
  mapping(address => bool) public isArdentisVault;

  /// CONSTRUCTOR
  /// @param ardentis The address of the Ardentis contract.
  constructor(address ardentis) {
    if (ardentis == address(0)) revert ErrorsLib.ZeroAddress();

    ARDENTIS = ardentis;

    _disableInitializers();
  }

  /// @dev Initializes the contract.
  /// @param admin The new admin of the contract.
  function initialize(address admin) public initializer {
    if (admin == address(0)) revert ErrorsLib.ZeroAddress();

    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
  }

  /* EXTERNAL */

  /// @inheritdoc IArdentisVaultFactory
  /// @dev Parameters `curator`, `guardian`, and `timeLockDelay` are not actually used in the vault creation logic.
  /// They are just followed interface's function definition.
  function createArdentisVault(
    address manager,
    address curator,
    address guardian,
    uint256 timeLockDelay,
    address asset,
    string memory name,
    string memory symbol
  ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address, address, address) {
    require(IERC20Metadata(asset).decimals() == 18, "Asset must have 18 decimals");

    ERC1967Proxy proxy = new ERC1967Proxy(
      address(ARDENTIS_VAULT_IMPL_18),
      abi.encodeWithSignature(
        "initialize(address,address,address,string,string)",
        manager,
        manager,
        asset,
        name,
        symbol
      )
    );

    isArdentisVault[address(proxy)] = true;

    // Just emit an event to track the creation of the vault like in the ArdentisVaultFactory
    emit EventsLib.CreateArdentisVault(
      address(proxy),
      address(ARDENTIS_VAULT_IMPL_18),
      manager,
      curator,
      timeLockDelay,
      msg.sender,
      manager,
      curator,
      guardian,
      asset,
      name,
      symbol
    );

    return (address(proxy), manager, curator);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
