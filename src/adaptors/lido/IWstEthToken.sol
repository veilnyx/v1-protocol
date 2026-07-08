// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWstEthToken is IERC20 {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    function getWstETHByStETH(uint256 _stETHAmount) external returns (uint256);

    function getStETHByWstETH(uint256 _wstETHAmount) external returns (uint256);
}
