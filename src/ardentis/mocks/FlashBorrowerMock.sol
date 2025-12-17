// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IArdentis } from "../interfaces/IArdentis.sol";
import { IArdentisFlashLoanCallback } from "../interfaces/IArdentisCallbacks.sol";

contract FlashBorrowerMock is IArdentisFlashLoanCallback {
  IArdentis private immutable ARDENTIS;

  constructor(IArdentis newArdentis) {
    ARDENTIS = newArdentis;
  }

  function flashLoan(address token, uint256 assets, bytes calldata data) external {
    ARDENTIS.flashLoan(token, assets, data);
  }

  function onArdentisFlashLoan(uint256 assets, bytes calldata data) external {
    require(msg.sender == address(ARDENTIS));
    address token = abi.decode(data, (address));
    IERC20(token).approve(address(ARDENTIS), assets);
  }
}
