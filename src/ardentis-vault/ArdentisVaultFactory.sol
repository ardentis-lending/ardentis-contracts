// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IArdentisVault } from "./interfaces/IArdentisVault.sol";
import { IArdentisVaultFactory } from "./interfaces/IArdentisVaultFactory.sol";
import { TimeLock } from "timelock/TimeLock.sol";

import { EventsLib } from "./libraries/EventsLib.sol";
import { ErrorsLib } from "./libraries/ErrorsLib.sol";

/// @title ArdentisVaultFactory
/// @notice This contract allows to create ArdentisVault, and to index them easily.
contract ArdentisVaultFactory is UUPSUpgradeable, AccessControlEnumerableUpgradeable, IArdentisVaultFactory {
  /* IMMUTABLES */

  /// @inheritdoc IArdentisVaultFactory
  address public immutable ARDENTIS;

  address public constant ARDENTIS_VAULT_IMPL_18 = 0xA1f832c7C7ECf91A53b4ff36E0ABdb5133C15982;

  address public vaultAdmin;

  bytes32 public constant MANAGER = keccak256("MANAGER"); // manager role
  bytes32 public constant CURATOR = keccak256("CURATOR"); // curator role
  bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
  bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
  bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

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
  /// @param _vaultAdmin The admin of vaults created by this contract.
  function initialize(address admin, address _vaultAdmin) public initializer {
    if (admin == address(0)) revert ErrorsLib.ZeroAddress();
    if (_vaultAdmin == address(0)) revert ErrorsLib.ZeroAddress();

    __AccessControl_init();

    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    vaultAdmin = _vaultAdmin;

    emit EventsLib.SetVaultAdmin(_vaultAdmin);
  }

  /* EXTERNAL */

  /// @inheritdoc IArdentisVaultFactory
  function createArdentisVault(
    address manager,
    address curator,
    address guardian,
    uint256 timeLockDelay,
    address asset,
    string memory name,
    string memory symbol
  ) external returns (address, address, address) {
    require(IERC20Metadata(asset).decimals() == 18, "Asset must have 18 decimals");

    address[] memory managerProposers = new address[](1);
    managerProposers[0] = manager;
    address[] memory managerExecutors = new address[](1);
    managerExecutors[0] = manager;

    address[] memory curatorProposers = new address[](1);
    curatorProposers[0] = curator;
    address[] memory curatorExecutors = new address[](1);
    curatorExecutors[0] = curator;

    /// create timeLock
    TimeLock managerTimeLock = new TimeLock(managerProposers, managerExecutors, address(this), timeLockDelay);

    {
      // transfer roles
      managerTimeLock.grantRole(CANCELLER_ROLE, guardian);
      managerTimeLock.grantRole(DEFAULT_ADMIN_ROLE, address(managerTimeLock));
      managerTimeLock.revokeRole(DEFAULT_ADMIN_ROLE, address(this));
    }

    TimeLock curatorTimeLock = new TimeLock(curatorProposers, curatorExecutors, address(this), timeLockDelay);

    {
      // transfer roles
      curatorTimeLock.grantRole(CANCELLER_ROLE, guardian);
      curatorTimeLock.grantRole(DEFAULT_ADMIN_ROLE, address(curatorTimeLock));
      curatorTimeLock.revokeRole(DEFAULT_ADMIN_ROLE, address(this));
    }

    ERC1967Proxy proxy = new ERC1967Proxy(
      address(ARDENTIS_VAULT_IMPL_18),
      abi.encodeWithSignature(
        "initialize(address,address,address,string,string)",
        address(this),
        address(this),
        asset,
        name,
        symbol
      )
    );

    {
      // transfer roles
      IArdentisVault vault = IArdentisVault(address(proxy));

      vault.grantRole(DEFAULT_ADMIN_ROLE, vaultAdmin);
      vault.grantRole(MANAGER, address(managerTimeLock));
      vault.grantRole(CURATOR, address(curatorTimeLock));

      vault.revokeRole(CURATOR, address(this));
      vault.revokeRole(MANAGER, address(this));
      vault.revokeRole(DEFAULT_ADMIN_ROLE, address(this));
    }

    isArdentisVault[address(proxy)] = true;

    emit EventsLib.CreateArdentisVault(
      address(proxy),
      address(ARDENTIS_VAULT_IMPL_18),
      address(managerTimeLock),
      address(curatorTimeLock),
      timeLockDelay,
      msg.sender,
      manager,
      curator,
      guardian,
      asset,
      name,
      symbol
    );

    return (address(proxy), address(managerTimeLock), address(curatorTimeLock));
  }

  function setVaultAdmin(address _vaultAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_vaultAdmin == address(0)) revert ErrorsLib.ZeroAddress();
    if (_vaultAdmin == vaultAdmin) revert ErrorsLib.AlreadySet();
    vaultAdmin = _vaultAdmin;

    emit EventsLib.SetVaultAdmin(_vaultAdmin);
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
