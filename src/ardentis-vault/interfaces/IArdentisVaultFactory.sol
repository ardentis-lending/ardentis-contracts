// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IArdentisVault } from "./IArdentisVault.sol";

/// @title IArdentisVaultFactory
/// @notice Interface of ArdentisVault's factory.
interface IArdentisVaultFactory {
  /// @notice The address of the Ardentis contract.
  function ARDENTIS() external view returns (address);

  /// @notice Whether a ArdentisVault was created with the factory.
  function isArdentisVault(address target) external view returns (bool);

  /// @notice Creates a new ArdentisVault.
  /// @param manager The manager of the vault.
  /// @param curator The curator of the vault.
  /// @param guardian The guardian of the vault.
  /// @param timeLockDelay The delay for the time lock.
  /// @param asset The address of the underlying asset.
  /// @param name The name of the vault.
  /// @param symbol The symbol of the vault.
  function createArdentisVault(
    address manager,
    address curator,
    address guardian,
    uint256 timeLockDelay,
    address asset,
    string memory name,
    string memory symbol
  ) external returns (address vault, address managerTimeLock, address curatorTimeLock);
}
