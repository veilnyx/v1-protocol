// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MemPoolProxy is ERC1967Proxy {
    constructor(
        address memPoolImpl,
        bytes memory initializeData
    ) ERC1967Proxy(memPoolImpl, initializeData) {}
}
