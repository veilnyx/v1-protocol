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
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(verifier22),
            selector: verifier22.verifyProof.selector
        });
        _verifier = new Verifier(
            vInfos,
            [REVOKER_PUBLIC_KEY_X, REVOKER_PUBLIC_KEY_Y],
            [ENCRYPTION_PUBLIC_KEY_X, ENCRYPTION_PUBLIC_KEY_Y]
        );
    }

    function test_PublicKeys() public view {
        uint256[2] memory revokerPubKey = _verifier.getRevokerPublicKey();
        uint256[2] memory encryptionPubKey = _verifier.getEncryptionPublicKey();
        assertEq(revokerPubKey[0], REVOKER_PUBLIC_KEY_X);
        assertEq(revokerPubKey[1], REVOKER_PUBLIC_KEY_Y);
        assertEq(encryptionPubKey[0], ENCRYPTION_PUBLIC_KEY_X);
        assertEq(encryptionPubKey[1], ENCRYPTION_PUBLIC_KEY_Y);
    }

    function test_getVerifierId() public view {
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
