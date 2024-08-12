// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddress.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolBaseTest} from "test/fixtures/PoolBaseTest.sol";

contract PoolUserRegistration is PoolBaseTest {
    ShieldedAddressRegistrationData addressRegistrationData;

    function setUp() public {
        _setUp();
        (, uint256 senderPk) = makeAddrAndKey("sender");

        addressRegistrationData = _loadShieldedAddressRegistrationData(
            "register_sender"
        );
        bytes memory shieldedAddress = bytes.concat(
            bytes32(fixture.sender.rootAddress),
            bytes32(fixture.sender.signPublicKey[0]),
            bytes32(fixture.sender.signPublicKey[1]),
            bytes32(fixture.sender.viewPublicKey[0]),
            bytes32(fixture.sender.viewPublicKey[1])
        );

        addressRegistrationData.signature = _getRegisterAddressSignature(
            senderPk,
            shieldedAddress
        );
    }

    function test_packShieldedAddress() public view {
        bytes memory compressed = fixture.sender.shieldedAddress;
        bytes memory uncompressed = abi.encodePacked(
            fixture.sender.rootAddress,
            fixture.sender.signPublicKey,
            fixture.sender.viewPublicKey
        );
        bytes memory compressed2 = ShieldedAddressLogic.pack(uncompressed);

        assertEq(compressed2.length, 96);
        assertEq(compressed, compressed2);
    }

    function test_registerAddress() public {
        // vm.expectEmit(false, false, false, false);
        // emit IPool.RegisterAddress(
        //     senderAddr,
        //     fixture.sender.rootAddress,
        //     0,
        //     shieldedAddress
        // );
        pool.registerAddress(addressRegistrationData);
    }

    function test_userRegistrationWhenPaused() external {
        pool.pause();

        ShieldedAddressRegistrationData
            memory data = _loadShieldedAddressRegistrationData(
                "register_sender"
            );
        vm.expectRevert(
            abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector)
        );
        pool.registerAddress(data);
    }

    function test_revertWhenAlreadyRegistered() external {
        pool.registerAddress(addressRegistrationData);
        uint256 rootAddress = uint256(
            bytes32(addressRegistrationData.shieldedAddress)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.RootAddressAlreadyRegistered.selector,
                rootAddress
            )
        );

        pool.registerAddress(addressRegistrationData);
    }
}
