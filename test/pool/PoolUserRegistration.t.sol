// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MESSAGE_REGISTER_ADDRESS, EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, EIP712_TYPEHASH_REGISTER_ADDRESS} from "src/base/Constants.sol";

contract PoolUserRegistration is PoolTest {
    address userAddr;
    uint256 userPK;
    bytes shieldedAddress;
    bytes signature;

    bytes32 private constant TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    function setUp() public {
        _initFixture();
        (userAddr, userPK) = makeAddrAndKey("userAddr");
        shieldedAddress = bytes.concat(
            bytes32(keccak256("rootAddress")),
            keccak256("sign"),
            keccak256("view")
        );
        signature = _getRegisterAddressSignature();
    }

    function _domainSeperator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TYPE_HASH,
                    keccak256(bytes(EIP712_DOMAIN_NAME)),
                    keccak256(bytes(EIP712_DOMAIN_VERSION)),
                    block.chainid,
                    address(pool)
                )
            );
    }

    function _getHashTypedRegisterAddressStruct()
        internal
        view
        returns (bytes32)
    {
        bytes32 hashTypedData = MessageHashUtils.toTypedDataHash(
            _domainSeperator(),
            keccak256(
                abi.encode(
                    EIP712_TYPEHASH_REGISTER_ADDRESS,
                    keccak256(bytes(MESSAGE_REGISTER_ADDRESS)),
                    keccak256(shieldedAddress)
                )
            )
        );
        return hashTypedData;
    }

    function _getRegisterAddressSignature()
        internal
        view
        returns (bytes memory)
    {
        bytes32 hashTypedData = _getHashTypedRegisterAddressStruct();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, hashTypedData);
        return abi.encodePacked(r, s, v);
    }

    function test_registerAddress() public {
        bytes32 hashTypedData = _getHashTypedRegisterAddressStruct();
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
