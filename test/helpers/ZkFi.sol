// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";
import {JsFFI} from "./JsFFI.sol";
import {ZAccount, ZAccountLogic} from "./ZAccount.sol";
import {ZTransaction, ZTransactionType} from "src/libraries/ZTransaction.sol";
import {TransactionRequest, TransactionRequestLogic} from "./TransactionRequest.sol";

contract ZKFi is JsFFI {
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

    // function loadZTxFixture(
    //     string memory name
    // ) external view returns (ZTransaction memory) {
    //     string memory path = string.concat(
    //         vm.projectRoot(),
    //         string.concat("/test/fixtures/ztx/", name, ".txt")
    //     );
    //     string memory file = vm.readFile(path);
    //     bytes memory data = vm.parseBytes(file);
    //     ZTransaction memory ztx = abi.decode(data, (ZTransaction));
    //     return ztx;
    // }
}
