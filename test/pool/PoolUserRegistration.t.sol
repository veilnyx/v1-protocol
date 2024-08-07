// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddress.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";

contract PoolUserRegistration is PoolTest {
    // address userAddr;
    // uint256 userPK;
    // bytes shieldedAddress;
    // bytes signature;

    function setUp() public {
        _initFixture();
        // (userAddr, userPK) = makeAddrAndKey("userAddr");
        // shieldedAddress = bytes.concat(
        //     bytes32(keccak256("rootAddress")),
        //     keccak256("sign"),
        //     keccak256("view")
        // );
        // signature = _getRegisterAddressSignature(userPK, shieldedAddress);
    }

    function test_compressShieldedAddress() public view {
        // ShieldedAddressRegistrationData
        //     memory data = _loadShieldedAddressRegistrationData(
        //         "register_sender"
        //     );

        bytes memory compressed = fixture.sender.shieldedAddress;
        bytes memory uncompressed = bytes.concat(
            bytes32(fixture.sender.rootAddress),
            bytes32(fixture.sender.signPublicKey[0]),
            bytes32(fixture.sender.signPublicKey[1]),
            bytes32(fixture.sender.viewPublicKey[0]),
            bytes32(fixture.sender.viewPublicKey[1])
        );

        console2.log(fixture.sender.signPublicKey[0]);

        bytes memory compressed2 = ShieldedAddressLogic.compress(uncompressed);

        // console2.logBytes(uncompressed);
        // console2.log("==================");
        // console2.logBytes(compressed);
        // console2.log("==================");
        // console2.logBytes(compressed2);

        assertEq(compressed2.length, 96);
        // assertEq(compressed, compressed2);
        // assertEq(addressRegData.shieldedAddress.length, compressed);

        // assertEq(compressed.length, 32);
    }

    // function test_registerAddress() public {
    //     bytes32 hashTypedData = _getHashTypedRegisterAddressStruct(
    //         shieldedAddress
    //     );
    //     address recovered = ECDSA.recover(hashTypedData, signature);
    //     assertEq(userAddr, recovered);

    //     uint256 rootAddr = uint256(bytes32(shieldedAddress));
    //     uint32 nextLeafIndex = pool.getAddressTreeNextLeafIndex();

    //     vm.expectEmit(true, true, true, true);
    //     emit IPool.RegisterAddress(
    //         userAddr,
    //         rootAddr,
    //         nextLeafIndex,
    //         shieldedAddress
    //     );
    // pool.registerAddress(shieldedAddress, signature);
    // }

    // function test_userRegistrationWhenPaused() external {
    //     pool.pause();
    //     vm.expectRevert(
    //         abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector)
    //     );
    //     vm.prank(userAddr);
    // pool.registerAddress(shieldedAddress, signature);
    // }

    // function test_revertWhenAlreadyRegistered() external {
    //     uint256 rootAddr = uint256(bytes32(shieldedAddress));
    // pool.registerAddress(shieldedAddress, signature);
    // vm.expectRevert(
    //     abi.encodeWithSelector(
    //         IPool.RootAddressAlreadyRegistered.selector,
    //         rootAddr
    //     )
    // );
    // vm.prank(userAddr);
    // pool.registerAddress(shieldedAddress, signature);
    // }
}
