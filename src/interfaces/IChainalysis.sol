// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IChainalysis {
    error SanctionedAddress(address addr);

    function isSanctioned(address addr) external view returns (bool);
}
