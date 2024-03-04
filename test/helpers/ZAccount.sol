// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {JsFFI} from "./JsFFI.sol";

struct ZAccount {
    uint256 seed;
    uint256 signPublicKey;
    uint256 viewPublicKey;
}

library ZAccountLogic {
    function addr(ZAccount memory self) public pure returns (bytes memory) {
        return
            bytes.concat(
                bytes32(self.signPublicKey),
                bytes32(self.viewPublicKey)
            );
    }

    // function generate(uint256 seed, JsFFI ffi) public returns (Account memory) {
    //     bytes memory res = ffi.runScript(
    //         "genAccount",
    //         string(abi.encode(seed))
    //     );
    //     Account memory account = abi.decode(res, (Account));
    //     return account;
    // }
}
