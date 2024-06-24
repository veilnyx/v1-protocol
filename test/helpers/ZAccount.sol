// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {JsFFI} from "./JsFFI.sol";

struct ZAccount {
    uint256 seed;
    uint256 rootAddress;
    uint256 signPublicKey;
    uint256 viewPublicKey;
}

library ZAccountLogic {
    function addr(ZAccount memory self) public pure returns (bytes memory) {
        return
            bytes.concat(
                bytes32(self.rootAddress),
                bytes32(self.signPublicKey),
                bytes32(self.viewPublicKey)
            );
    }
}
