// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {IScreener} from "../interfaces/IScreener.sol";
import {ISanctionsList} from "../interfaces/ISanctionsList.sol";

contract Screener is IScreener {
    address public immutable sanctionsList;

    constructor(address sanctionsList_) {
        sanctionsList = sanctionsList_;
    }

    function isSanctioned(
        address account
    ) external view override returns (bool) {
        return ISanctionsList(sanctionsList).isSanctioned(account);
    }
}
