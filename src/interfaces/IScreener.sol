// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISanctionsList} from "./ISanctionsList.sol";

interface IScreener is ISanctionsList {
    error SanctionedAddress(address addr);
}
