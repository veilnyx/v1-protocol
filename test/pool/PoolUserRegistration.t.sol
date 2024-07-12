// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

contract PoolUserRegistration is PoolTest {
    address userAddr;
    uint256 userPK;
    bytes shieldedAddress;
    bytes signature;

    function setUp() public {
        _initFixture();
        (userAddr, userPK) = makeAddrAndKey("userAddr");
        shieldedAddress = bytes.concat(
            bytes32(keccak256("rootAddress")),
            keccak256("sign"),
            keccak256("view")
        );
        signature = _getRegisterAddressSignature(userPK, shieldedAddress);
    }

    function test_registerAddress() public {
        bytes32 hashTypedData = _getHashTypedRegisterAddressStruct(
            shieldedAddress
        );
        address recovered = ECDSA.recover(hashTypedData, signature);
        assertEq(userAddr, recovered);

        uint256 rootAddr = uint256(bytes32(shieldedAddress));
        uint32 nextLeafIndex = pool.getAddressTreeNextLeafIndex();

        vm.expectEmit(true, true, true, true);
        emit IPool.RegisterAddress(
            userAddr,
            rootAddr,
            nextLeafIndex,
            shieldedAddress
        );
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

    function test_revertWhenAlreadyRegistered() external {
        uint256 rootAddr = uint256(bytes32(shieldedAddress));
        pool.registerAddress(shieldedAddress, signature);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.RootAddressAlreadyRegistered.selector,
                rootAddr
            )
        );
        vm.prank(userAddr);
        pool.registerAddress(shieldedAddress, signature);
    }
}
