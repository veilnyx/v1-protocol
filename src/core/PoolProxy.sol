// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PoolProxy is ERC1967Proxy {
    constructor(
        address poolImpl,
        bytes memory initializeData
    ) ERC1967Proxy(poolImpl, initializeData) {}
}
