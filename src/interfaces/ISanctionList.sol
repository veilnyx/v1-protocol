// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISanctionList {
    function isSanctioned(address addr) external view returns (bool);
}
