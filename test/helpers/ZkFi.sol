// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";
import {JsFFI} from "./JsFFI.sol";
import {ZAccount, ZAccountLogic} from "./ZAccount.sol";
import {ZTransaction, ZTransactionType} from "../../../src/libraries/ZTransaction.sol";
import {Proof} from "../../../src/libraries/DataTypes.sol";
import {TransactionRequest, TransactionRequestLogic} from "./TransactionRequest.sol";

contract ZkFi is JsFFI {
    using TransactionRequestLogic for TransactionRequest;

    function genAccount(uint256 seed) public returns (ZAccount memory) {
        bytes memory res = runScript(
            "genAccount",
            vm.toString(abi.encode(seed))
        );
        ZAccount memory account = abi.decode(res, (ZAccount));
        return account;
    }

    function getZTx(
        TransactionRequest memory req
    ) public returns (ZTransaction memory) {
        bytes memory data = runScript("genZTx", vm.toString(req.encode()));
        ZTransaction memory ztx = abi.decode(data, (ZTransaction));
        return ztx;
    }

    function getZTxAndHash(
        TransactionRequest memory req
    ) public returns (uint256, ZTransaction memory) {
        bytes memory data = runScript(
            "genZTxAndHash",
            vm.toString(req.encode())
        );
        (uint256 txHash, ZTransaction memory ztx) = _getZTxAndHash(data);
        return (txHash, ztx);
    }

    function _getZTxAndHash(
        bytes memory data
    ) internal pure returns (uint256, ZTransaction memory) {
        (uint256 txHash, ZTransaction memory ztx) = abi.decode(
            data,
            (uint256, ZTransaction)
        );

        return (txHash, ztx);
    }
}
