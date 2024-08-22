// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IScreener} from "../interfaces/IScreener.sol";
import {ISanctionList} from "../interfaces/ISanctionList.sol";

contract Screener is IScreener {
    address public immutable sanctionList;

    constructor(address sanctionList_) {
        sanctionList = sanctionList_;
    }

    function isSanctioned(
        address account
    ) external view override returns (bool) {
        return ISanctionList(sanctionList).isSanctioned(account);
    }
}
