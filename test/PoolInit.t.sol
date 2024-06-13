// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

contract PoolInitTest is PoolTest {
    function setUp() public {
        _initFixture();
    }

    function test_correctParameters() public view {
        address verifier_ = pool.verifier();
        address convertor_ = pool.convertor();
        (uint256 revokerKeyX, uint256 revokerKeyY) = pool.getRevokerPublicKey();
        (uint256 encryptionKeyX, uint256 encryptionKeyY) = pool
            .getEncryptionPublicKey();

        assertEq(verifier_, address(verifier));
        assertEq(convertor_, address(convertor));
        assertEq(revokerKeyX, fixture.revokerPublicKey[0]);
        assertEq(revokerKeyY, fixture.revokerPublicKey[1]);
        assertEq(encryptionKeyX, fixture.encryptionPublicKey[0]);
        assertEq(encryptionKeyY, fixture.encryptionPublicKey[1]);
    }
}
