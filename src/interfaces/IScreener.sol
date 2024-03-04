// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "../interfaces/ISanctionsList.sol";

interface IScreener is ISanctionsList {
    error SanctionedAddress(address addr);

    function isSanctioned(address addr) external view returns (bool);
}
