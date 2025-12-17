// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IArdentisLiquidateCallback
/// @notice Interface that liquidators willing to use `liquidate`'s callback must implement.
interface IArdentisLiquidateCallback {
  /// @notice Callback called when a liquidation occurs.
  /// @dev The callback is called only if data is not empty.
  /// @param repaidAssets The amount of repaid assets.
  /// @param data Arbitrary data passed to the `liquidate` function.
  function onArdentisLiquidate(uint256 repaidAssets, bytes calldata data) external;
}

/// @title IArdentisRepayCallback
/// @notice Interface that users willing to use `repay`'s callback must implement.
interface IArdentisRepayCallback {
  /// @notice Callback called when a repayment occurs.
  /// @dev The callback is called only if data is not empty.
  /// @param assets The amount of repaid assets.
  /// @param data Arbitrary data passed to the `repay` function.
  function onArdentisRepay(uint256 assets, bytes calldata data) external;
}

/// @title IArdentisSupplyCallback
/// @notice Interface that users willing to use `supply`'s callback must implement.
interface IArdentisSupplyCallback {
  /// @notice Callback called when a supply occurs.
  /// @dev The callback is called only if data is not empty.
  /// @param assets The amount of supplied assets.
  /// @param data Arbitrary data passed to the `supply` function.
  function onArdentisSupply(uint256 assets, bytes calldata data) external;
}

/// @title IArdentisSupplyCollateralCallback
/// @notice Interface that users willing to use `supplyCollateral`'s callback must implement.
interface IArdentisSupplyCollateralCallback {
  /// @notice Callback called when a supply of collateral occurs.
  /// @dev The callback is called only if data is not empty.
  /// @param assets The amount of supplied collateral.
  /// @param data Arbitrary data passed to the `supplyCollateral` function.
  function onArdentisSupplyCollateral(uint256 assets, bytes calldata data) external;
}

/// @title IArdentisFlashLoanCallback
/// @notice Interface that users willing to use `flashLoan`'s callback must implement.
interface IArdentisFlashLoanCallback {
  /// @notice Callback called when a flash loan occurs.
  /// @dev The callback is called only if data is not empty.
  /// @param assets The amount of assets that was flash loaned.
  /// @param data Arbitrary data passed to the `flashLoan` function.
  function onArdentisFlashLoan(uint256 assets, bytes calldata data) external;
}
