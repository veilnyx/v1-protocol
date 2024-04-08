// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ZAccount} from "../helpers/ZAccount.sol";
import {ZkFi} from "../helpers/ZkFi.sol";
import {TransactionRequest} from "../helpers/TransactionRequest.sol";
import {ZAccountLogic} from "../helpers/ZAccount.sol";
import {ZTransactionType, ZTransaction} from "src/libraries/ZTransaction.sol";

abstract contract BaseFixture is Test {
    using ZAccountLogic for ZAccount;

    uint256 public constant REVOKER_PUBLIC_KEY_X =
        8116072818876777666029027213729376705234613448128995613697283149497235402123;
    uint256 public constant REVOKER_PUBLIC_KEY_Y =
        4598772416842731049226007701899382609184728232075557894618791492264594188716;

    uint256 public constant ENCRYPTION_PUBLIC_KEY_X =
        18136749973959690676930643759397962821618865161533601684883289116728073483917;
    uint256 public constant ENCRYPTION_PUBLIC_KEY_Y =
        7818464758266392754559612367237682152094555123891341826265694881788827476134;

    ZkFi public zkfi;

    ZAccount public sender;
    ZAccount public receiver;
    address public withdrawAddress;

    function _initFixture() internal virtual {
        zkfi = new ZkFi();

        sender = zkfi.genAccount(uint256(keccak256("sender")));
        receiver = zkfi.genAccount(uint256(keccak256("receiver")));
        withdrawAddress = address(bytes20(keccak256("withdrawAddress")));
    }

    function _createDepositReq(
        uint24 assetId,
        uint256 value
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory assetIds = new uint24[](1);
        assetIds[0] = assetId;
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        return _createTxReq(ZTransactionType.DEPOSIT, assetIds, values);
    }

    function _createDepositReq(
        uint24 assetId1,
        uint256 value1,
        uint24 assetId2,
        uint256 value2
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory _assetIds = new uint24[](2);
        _assetIds[0] = assetId1;
        _assetIds[1] = assetId2;
        uint256[] memory _values = new uint256[](2);
        _values[0] = value1;
        _values[1] = value2;
        return _createTxReq(ZTransactionType.DEPOSIT, _assetIds, _values);
    }

    function _createTransferReq(
        uint24 assetId,
        uint256 value
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory assetIds = new uint24[](1);
        assetIds[0] = assetId;
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        return _createTxReq(ZTransactionType.TRANSFER, assetIds, values);
    }

    function _createTransferReq(
        uint24 assetId1,
        uint256 value1,
        uint24 assetId2,
        uint256 value2
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory _assetIds = new uint24[](2);
        _assetIds[0] = assetId1;
        _assetIds[1] = assetId2;
        uint256[] memory _values = new uint256[](2);
        _values[0] = value1;
        _values[1] = value2;
        return _createTxReq(ZTransactionType.TRANSFER, _assetIds, _values);
    }

    function _createWithdrawReq(
        uint24 assetId,
        uint256 value
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory assetIds = new uint24[](1);
        assetIds[0] = assetId;
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        return _createTxReq(ZTransactionType.WITHDRAW, assetIds, values);
    }

    function _createWithdrawReq(
        uint24 assetId1,
        uint256 value1,
        uint24 assetId2,
        uint256 value2
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory _assetIds = new uint24[](2);
        _assetIds[0] = assetId1;
        _assetIds[1] = assetId2;
        uint256[] memory _values = new uint256[](2);
        _values[0] = value1;
        _values[1] = value2;
        return _createTxReq(ZTransactionType.WITHDRAW, _assetIds, _values);
    }

    function _createConvertReq(
        uint24 assetId,
        uint256 value
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory assetIds = new uint24[](1);
        assetIds[0] = assetId;
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        return _createTxReq(ZTransactionType.CONVERT, assetIds, values);
    }

    function _createConvertReq(
        uint24 assetId1,
        uint256 value1,
        uint24 assetId2,
        uint256 value2
    ) internal view returns (TransactionRequest memory) {
        uint24[] memory _assetIds = new uint24[](2);
        _assetIds[0] = assetId1;
        _assetIds[1] = assetId2;
        uint256[] memory _values = new uint256[](2);
        _values[0] = value1;
        _values[1] = value2;
        return _createTxReq(ZTransactionType.CONVERT, _assetIds, _values);
    }

    function _createTxReq(
        ZTransactionType txType,
        uint24[] memory assetIds,
        uint256[] memory values
    ) internal view returns (TransactionRequest memory) {
        bytes memory to;
        if (txType == ZTransactionType.WITHDRAW) {
            to = abi.encode(withdrawAddress);
        } else if (txType == ZTransactionType.CONVERT) {
            to = abi.encode(address(0));
        } else {
            to = receiver.addr();
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
