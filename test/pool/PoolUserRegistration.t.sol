// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PoolInitTest is PoolTest {
    address userAddr;
    uint256 userPK;
    uint256 user = uint256(uint160(userAddr));
    bytes publicKeys;
    bytes signature;

    function setUp() public {
        _initFixture();
        (userAddr, userPK) = makeAddrAndKey("userAddr");
        
        bytes32 userPublicKeyX = bytes32(user);
        bytes32 userPublicKeyY = bytes32(user);

        publicKeys = bytes.concat(userPublicKeyX, userPublicKeyY);
        signature;

        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
            bytes.concat(bytes32(user), publicKeys)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, msgHash);
        signature = abi.encodePacked(r, s, v);
    }

    function test_register_user() public {
        vm.expectEmit(true, true, true, false, address(pool));
        emit IPool.RegisterAddress(userAddr, user, 1, publicKeys);

        vm.prank(userAddr);
        pool.register(user, publicKeys, signature);
    }

     function test_userRegistrationWhenPaused() external {
        pool.pause();
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.prank(userAddr);
        pool.register(user, publicKeys, signature);
    }
}
