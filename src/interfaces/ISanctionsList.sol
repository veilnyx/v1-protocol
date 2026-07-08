// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

interface ISanctionsList {
    function isSanctioned(address addr) external view returns (bool);
}
