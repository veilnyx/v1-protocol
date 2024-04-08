// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {PoolFixture} from "./fixtures/PoolFixture.sol";

contract PoolInitTest is PoolFixture {
    function setUp() public {
        _initFixture();
    }

    function test_correctParameters() public view {
        address verifier_ = pool.verifier();
        address convertor_ = pool.convertor();
        address entryPoint_ = pool.entryPoint();
        (uint256 revokerKeyX, uint256 revokerKeyY) = pool.getRevokerPublicKey();
        (uint256 encryptionKeyX, uint256 encryptionKeyY) = pool
            .getEncryptionPublicKey();

        assertEq(verifier_, address(verifier));
        assertEq(convertor_, address(convertor));
        assertEq(entryPoint_, entryPoint);
        assertEq(revokerKeyX, REVOKER_PUBLIC_KEY_X);
        assertEq(revokerKeyY, REVOKER_PUBLIC_KEY_Y);
        assertEq(encryptionKeyX, ENCRYPTION_PUBLIC_KEY_X);
        assertEq(encryptionKeyY, ENCRYPTION_PUBLIC_KEY_Y);
    }
}
