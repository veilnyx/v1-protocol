// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {REGISTER_ADDRESS_MESSASGE_PREFIX} from "src/base/Constants.sol";

contract PoolInitTest is PoolTest {
    address userAddr;
    uint256 userPK;
    uint256 userRootAddress = uint256(uint160(userAddr));
    bytes shieldedAddress;
    bytes signature;
    bytes32 private constant MERAL_PRIVATE_KEY =
        0x146f28e249d119e95c844861cc4a106bd74c11f849da3ef99635a37847e89ed1;

    function setUp() public {
        _initFixture();
        (userAddr, userPK) = makeAddrAndKey("userAddr");
        console.log("EOA address used to sign: %s", userAddr);
        shieldedAddress = bytes.concat(
            bytes32(userRootAddress),
            keccak256(bytes("sign")),
            keccak256(bytes("view"))
        );

        // preparing domainSeperator
        bytes32 domainSeperatorTypeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

        bytes32 domainSeperator = keccak256(
            abi.encode(
                domainSeperatorTypeHash,
                bytes("zkFi"),
                bytes("1"),
                11155420, // OP Sepolia
                address(pool)
            )
        );

        // preparing signing data struct hash
        bytes32 signingDataTypeHash = keccak256(
            "SigningDataStruct(bytes shieldedAddress,string message)"
        );

        bytes32 signingData = keccak256(
            abi.encode(
                signingDataTypeHash,
                shieldedAddress,
                keccak256(bytes(REGISTER_ADDRESS_MESSASGE_PREFIX))
            )
        );

        console.log("Test::domainSeparator:");
        console.logBytes32(domainSeperator);

        console.log("Test::signingData:");
        console.logBytes32(signingData);

        bytes32 msgHash = MessageHashUtils.toTypedDataHash(
            domainSeperator,
            signingData
        );

        console.log("Test:: msgHash: ");
        console.logBytes32(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, msgHash);
        signature = abi.encodePacked(r, s, v);
    }

    function test_registerAddress() public {
        // vm.expectEmit(true, true, true, false, address(pool));
        // emit IPool.RegisterAddress(
        //     userAddr,
        //     userRootAddress,
        //     1,
        //     shieldedAddress
        // );

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

    // function test_revertWhenAlreadyRegistered() external {
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IPool.DuplicateAddress.selector)
    //     );
    //     vm.prank(userAddr);
    //     pool.registerAddress(shieldedAddress, signature);
    // }
}
