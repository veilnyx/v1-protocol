// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {REGISTER_ADDRESS_MESSASGE_PREFIX} from "src/core/Constants.sol";

contract PoolInitTest is PoolTest {
    address userAddr;
    uint256 userPK;
    uint256 userRootAddress = uint256(uint160(userAddr));
    bytes shieldedAddress;
    bytes signature;

    function setUp() public {
        _initFixture();
        (userAddr, userPK) = makeAddrAndKey("userAddr");

        shieldedAddress = bytes.concat(
            bytes32(userRootAddress),
            keccak256(bytes("sign")),
            keccak256(bytes("view"))
        );

        bytes32 msgHash = MessageHashUtils.toEthSignedMessageHash(
            bytes.concat(REGISTER_ADDRESS_MESSASGE_PREFIX, shieldedAddress)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, msgHash);
        signature = abi.encodePacked(r, s, v);
    }

    function test_registerAddress() public {
        vm.expectEmit(true, true, true, false, address(pool));
        emit IPool.RegisterAddress(
            userAddr,
            userRootAddress,
            1,
            shieldedAddress
        );

        vm.prank(userAddr);
        pool.registerAddress(shieldedAddress, signature);
    }

    function test_userRegistrationWhenPaused() external {
        pool.pause();
        vm.expectRevert(
            abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector)
        );
        vm.prank(userAddr);
        pool.registerAddress(shieldedAddress, signature);
    }
}
