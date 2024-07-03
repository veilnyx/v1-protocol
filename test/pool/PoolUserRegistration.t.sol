// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {REGISTRATION_SIGNING_MSG} from "src/base/Constants.sol";

contract PoolUserRegistration is PoolTest {
    address userAddr;
    uint256 userPK;
    // TODO: make tests dynamic
    bytes shieldedAddress =
        hex"0443bb99ee8faff504b6db5ba4d00756816bcfa78cab8a748b6d36f8b90ac61e1a076c0c964d5b9e0c1fd8b5b03b98c6dda2f964ce3498a2a942e083b39c2634af4596ccb08ae47b49f8689af77c8cc4dfeece7153a79baf7c7615dc6560426c";
    bytes signature =
        hex"70e5e37f12b9185dce860df61a9a2540f7672b6c088d4b55c6816b1202506a2579191b5b10819e9532bf53985123084f0413f03d0d9bd249a58a881f9455d2601b";
    uint256 userRootAddress = uint256(bytes32(shieldedAddress));
    bytes32 private constant MERAL_PRIVATE_KEY =
        0x146f28e249d119e95c844861cc4a106bd74c11f849da3ef99635a37847e89ed1;

    function setUp() public {
        _initFixture();
        (userAddr, userPK) = makeAddrAndKey("userAddr");
        console.log("EOA address used to sign: %s", userAddr);
        console.log("Pool Addr:", address(pool));

        // shieldedAddress = bytes.concat(
        //     bytes32(userRootAddress),
        //     keccak256(bytes("sign")),
        //     keccak256(bytes("view"))
        // );
    }

    function test_registerAddress() public {
        address expectedSender = 0x38D9cFf58D233AF0B9c1434EEDE012009D23c971;

        vm.expectEmit(true, false, false, false);
        emit IPool.RegisterAddress(expectedSender, 0, 0, bytes(""));
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
        pool.registerAddress(shieldedAddress, signature);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPool.RootAddrAlreadyRegistered.selector,
                userRootAddress
            )
        );
        vm.prank(userAddr);
        pool.registerAddress(shieldedAddress, signature);
    }
}
