// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISanctionList} from "./ISanctionList.sol";

interface IScreener is ISanctionList {
    error SanctionedAddress(address addr);
}
