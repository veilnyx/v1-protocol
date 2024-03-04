// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Verifier} from "../../src/core/Verifier.sol";
import {Verifier22} from "../../src/verifiers/Verifier22.sol";
import {AssetType, VerifierInfo} from "../../src/libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType} from "../../src/libraries/ZTransaction.sol";

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TransactionRequest} from "./helpers/TransactionRequest.sol";
import {ZkFi, ZAccount} from "./helpers/ZkFi.sol";
import {BaseFixture} from "./fixtures/BaseFixture.sol";

contract VerifierTest is BaseFixture {
    Verifier internal _verifier;

    function setUp() public {
        _initFixture();
        Verifier22 verifier22 = new Verifier22();
        uint256[] memory ids = new uint256[](1);
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        ids[0] = 2 * 10 + 2;
        vInfos[0] = VerifierInfo({
            addr: address(verifier22),
            selector: verifier22.verifyProof.selector
        });
        _verifier = new Verifier(ids, vInfos);
    }

    function test_getVerifierId() public {
        uint256 id = _verifier.getVerifierId(2, 2);
        assertEq(id, 22);
    }

    function test_verifyDeposit() public {
        TransactionRequest memory req = _createDepositReq(0x010001, 100);
        ZTransaction memory ztx = zkfi.getZTx(req);
        bool isValid = _verifier.verifyTransactionProof(ztx);
        assertTrue(isValid);
    }

    function test_verifyTransfer() public {
        TransactionRequest memory req = _createTransferReq(0x010001, 100);
        ZTransaction memory ztx = zkfi.getZTx(req);
        bool isValid = _verifier.verifyTransactionProof(ztx);
        assertTrue(isValid);
    }

    function test_verifyWithdraw() public {
        TransactionRequest memory req = _createWithdrawReq(0x010001, 100);
        ZTransaction memory ztx = zkfi.getZTx(req);
        bool isValid = _verifier.verifyTransactionProof(ztx);
        assertTrue(isValid);
    }

    function test_verifyConvert() public {
        TransactionRequest memory req = _createConvertReq(0x010001, 100);
        ZTransaction memory ztx = zkfi.getZTx(req);
        bool isValid = _verifier.verifyTransactionProof(ztx);
        assertTrue(isValid);
    }
}
