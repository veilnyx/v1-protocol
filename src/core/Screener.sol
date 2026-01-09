// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IScreener} from "../interfaces/IScreener.sol";
import {IChainalysis} from "../interfaces/IChainalysis.sol";

/// @notice Currently integrates Chainalysis oracle contract for sanction screening.
/// @dev Screener contract implementing IScreener as expected by Pool, for future compatibility preventing core protocol upgrade. This contract can be replaced in future with a different screener implementation, if needed, without requiring a core protocol upgrade, just the address of the new screener contract to be added through `Pool::setScreener(address)`.
contract Screener is IScreener {
    address public immutable screener;

    constructor(address screener_) {
        screener = screener_;
    }

    function isSanctioned(
        address account
    ) external view override returns (bool) {
        return IChainalysis(screener).isSanctioned(account);
    }
}
