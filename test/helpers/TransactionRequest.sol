// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ZTransactionType} from "src/libraries/ZTransaction.sol";

struct TransactionRequest {
    ZTransactionType txType;
    uint24[] assetIds;
    uint256[] values;
    bytes to;
    bytes payload;
}

library TransactionRequestLogic {
    function encode(
        TransactionRequest memory self
    ) public pure returns (bytes memory) {
        return abi.encode(self);
    }
}
