// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ZTransactionType, ZTransaction} from "src/libraries/ZTransaction.sol";
import {ZAccount} from "test/helpers/ZAccount.sol";
import {ZKFi} from "test/helpers/ZKFi.sol";
import {Fixture, FixtureLib} from "test/fixtures/Fixture.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";
import {ZAccountLogic} from "test/helpers/ZAccount.sol";

abstract contract BaseTest is Test {
    using ZAccountLogic for ZAccount;

    ZKFi public zkfi;
    Fixture public fixture;

    constructor() {
        zkfi = new ZKFi();
        fixture = FixtureLib.load(zkfi);
    }

    function _loadZTx(
        string memory name
    ) internal view returns (ZTransaction memory) {
        return FixtureLib.loadZTx(name, vm);
    }

    function _createTxReq(
        ZTransactionType txType,
        uint24[] memory assetIds,
        uint256[] memory values
    ) internal view returns (TransactionRequest memory) {
        bytes memory to;
        if (txType == ZTransactionType.WITHDRAW) {
            to = abi.encode(fixture.withdrawAddress);
        } else if (txType == ZTransactionType.CONVERT) {
            to = abi.encode(address(0));
        } else {
            to = ZAccountLogic.addr(fixture.receiverAccount);
        }

        TransactionRequest memory req = TransactionRequest({
            txType: txType,
            assetIds: assetIds,
            values: values,
            to: to,
            payload: bytes("")
        });
        return req;
    }
}
