// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ErrorsLib
/// @author Ardentis
/// @notice Library exposing error messages.
library ErrorsLib {
  /// @dev Thrown when passing the zero address.
  string internal constant ZERO_ADDRESS = "zero address";

  /// @dev Thrown when the caller is not Ardentis.
  string internal constant NOT_ARDENTIS = "not Ardentis";

  /// @notice Thrown when the caller is not the admin.
  string internal constant NOT_ADMIN = "not admin";
}
