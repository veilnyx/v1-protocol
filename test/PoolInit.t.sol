// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "../../src/interfaces/IPool.sol";
import {Pool} from "../../src/core/Pool.sol";
import {Verifier} from "../../src/core/Verifier.sol";
import {Verifier22} from "../../src/verifiers/Verifier22.sol";
import {AssetType, VerifierInfo} from "../../src/libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType} from "../../src/libraries/ZTransaction.sol";

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ZkFi, ZAccount} from "./helpers/ZkFi.sol";
import {PoolFixture} from "./fixtures/PoolFixture.sol";
import {TransactionRequest} from "./helpers/TransactionRequest.sol";

contract PoolInitTest is PoolFixture {
    function setUp() public {
        _initFixture();
    }

    function test_correctParameters() public view {
        address verifier_ = pool.verifier();
        address convertor_ = pool.convertor();
        address entryPoint_ = pool.entryPoint();
        uint256[2] memory encryptionKey = pool.getEncryptionPublicKey();
        uint256[2] memory revokerKey = pool.getRevokerPublicKey();

        assertEq(verifier_, address(verifier));
        assertEq(convertor_, address(convertor));
        assertEq(entryPoint_, entryPoint);
        assertEq(encryptionKey[0], ENCRYPTION_PUBLIC_KEY_X);
        assertEq(encryptionKey[1], ENCRYPTION_PUBLIC_KEY_Y);
        assertEq(revokerKey[0], REVOKER_PUBLIC_KEY_X);
        assertEq(revokerKey[1], REVOKER_PUBLIC_KEY_Y);
    }
}
