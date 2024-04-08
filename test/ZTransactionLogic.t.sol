// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {AssetType, Asset} from "src/libraries/Asset.sol";
import {ZTransaction, ZTransactionLogic, ZTransactionType} from "src/libraries/ZTransaction.sol";

import {JsFFI} from "./helpers/JsFFI.sol";
import {ZkFi} from "./helpers/ZkFi.sol";
import {ZAccount, ZAccountLogic} from "./helpers/ZAccount.sol";
import {TransactionRequest, TransactionRequestLogic} from "./helpers/TransactionRequest.sol";

contract ZTransactionLogicTest is JsFFI {
    using ZAccountLogic for ZAccount;

    ZkFi public zkfi;
    ZAccount public ac;

    function setUp() public {
        zkfi = new ZkFi();
        ac = zkfi.genAccount(123);
    }

    function test_hash() public {
        uint24[] memory assetIds = new uint24[](1);
        assetIds[0] = 0x010001;
        uint256[] memory values = new uint256[](1);
        values[0] = 100;
        TransactionRequest memory req = TransactionRequest({
            txType: ZTransactionType.DEPOSIT,
            assetIds: assetIds,
            values: values,
            to: ac.addr(),
            payload: bytes("")
        });

        (uint256 txHash, ZTransaction memory ztx) = zkfi.getZTxAndHash(req);
        uint256 h = ZTransactionLogic.hash(ztx);

        console2.log("txHash", txHash);
        console2.log("h", h);

        // assertEq(h, txHash);
    }

    // function test_toVerifierInput() public {
    //     ZTransaction memory ztx;
    //     uint256[] memory proof = new uint256[](8);
    //     uint24[] memory pubAssetIds = new uint24[](2);
    //     uint256[] memory pubValues = new uint256[](2);
    //     uint256[] memory nullifiers = new uint256[](2);
    //     uint256[] memory commitments = new uint256[](2);
    //     bytes[] memory memos = new bytes[](2);

    //     ztx.txType = ZTransactionType.DEPOSIT;
    //     // ztx.proof = proof;
    //     ztx.merkleRoot = 123;
    //     ztx.pubAssetIds = pubAssetIds;
    //     ztx.pubValues = pubValues;
    //     ztx.nullifiers = nullifiers;
    //     ztx.commitments = commitments;
    //     ztx.memos = memos;
    //     ztx.feeData = 0;
    //     ztx.beneficiary = 123;
    //     // ztx.beneficiaryMemo = "memo3";
    //     // ztx.target = address(0x1234567890123456789012345678901234567890);
    //     // ztx.targetPayload = "payload";
    //     // ztx.ephPubKey = [1, 2];
    //     // ztx.encAssets = [3, 4];

    //     bytes memory inp = ZTransactionLogic.toVerifierInput(ztx);
    // }
}
