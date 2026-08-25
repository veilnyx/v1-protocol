// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddressLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IScreener} from "src/interfaces/IScreener.sol";
import {Screener} from "src/core/Screener.sol";
import {PoolBaseTest} from "test/fixtures/PoolBaseTest.sol";

contract PoolUserRegistration is PoolBaseTest {
    ShieldedAddressRegistrationData addressRegistrationData;
    ShieldedAddressRegistrationData addrRegDataWithProofVeriOutsourced;
    address senderAddr;
    uint256 senderPK;
    bytes shieldedAddress;

    error ShieldedAddrIncorrectLength(uint8 givenLength, uint8 expectedLength);

    function setUp() public {
        _setUp();
        // Deterministic registrant from config.json `.registrant` -- the same account the
        // fixture generator binds into the register proof as `publicAddress`.
        senderAddr = fixture.registrant.addr;
        senderPK = fixture.registrant.privateKey;

        addressRegistrationData = _loadShieldedAddressRegistrationData(
            "register_sender"
        );

        // addrRegDataWithProofVeriOutsourced = _loadShieldedAddressRegistrationData(
        //     "register_sender_proof_veri_outsourced"
        // );

        shieldedAddress = bytes.concat(
            bytes32(fixture.sender.rootAddress),
            bytes32(fixture.sender.signPublicKey[0]),
            bytes32(fixture.sender.signPublicKey[1]),
            bytes32(fixture.sender.viewPublicKey[0]),
            bytes32(fixture.sender.viewPublicKey[1])
        );

        bytes memory signature = _getRegisterAddressSignature(
            senderPK,
            shieldedAddress
        );
        addressRegistrationData.signature = signature;
        // addrRegDataWithProofVeriOutsourced.signature = signature;
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
        vm.expectEmit(true, true, false, false);
        emit IPool.RegisterAddress(
            senderAddr,
            fixture.sender.rootAddress,
            0,
            shieldedAddress
        );
        pool.registerAddress(addressRegistrationData);

        assertEq(addressRegistrationData.shieldedAddress, shieldedAddress);
    }

    /**
    function test_registerAddressWithProofVerificationOutsourced() public {
        vm.expectEmit(true, true, false, false);
        emit IPool.RegisterAddress(
            senderAddr,
            fixture.sender.rootAddress,
            0,
            shieldedAddress
        );
        pool.registerAddress(addrRegDataWithProofVeriOutsourced);

        assertEq(
            addrRegDataWithProofVeriOutsourced.shieldedAddress,
            shieldedAddress
        );
    }
     */

    function test_revertWhenShieldedAddrPacked() public {
        addressRegistrationData.shieldedAddress = fixture
            .sender
            .shieldedAddress; // packed

        vm.expectRevert(
            abi.encodeWithSelector(
                ShieldedAddrIncorrectLength.selector,
                uint8(96),
                uint8(160)
            )
        );
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

    //////////////////////////////////////////////////////
    /// Sanctioned Address Screening                //////
    //////////////////////////////////////////////////////

    uint256 internal constant ETH_MAINNET = 1;
    /// @dev Chainalysis sanctions oracle on Ethereum mainnet.
    address internal constant MAINNET_SANCTIONS_LIST =
        0x40C57923924B5c5c5455c48D93317139ADDaC8fb;
    /// @dev A sanctioned address taken from the mainnet `SanctionedAddressesAdded`
    /// event logs of the Chainalysis oracle.
    address internal constant SANCTIONED_ADDRESS =
        0xFda1Ec4A6178d4916b001a065422D31EBE5F62FF;

    /// @notice Registration must revert when the caller is sanctioned. Uses the
    /// dynamic MockScreener so only this test flags the caller; all other tests
    /// keep the default "not sanctioned" behaviour.
    function test_revertWhenSenderSanctioned() external {
        screener.setSanctioned(senderAddr, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScreener.SanctionedAddress.selector,
                senderAddr
            )
        );
        vm.prank(senderAddr);
        pool.registerAddress(addressRegistrationData);
    }

    /// @notice The zero-address screener kill-switch: once the owner disables
    /// screening via `setScreener(0)`, a previously-blocked sanctioned caller can
    /// register. The first (sanctioned) attempt reverts before any state change,
    /// so the same registration data is reused for the successful attempt.
    function test_registerSucceedsAfterScreenerDisabled() external {
        screener.setSanctioned(senderAddr, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IScreener.SanctionedAddress.selector,
                senderAddr
            )
        );
        vm.prank(senderAddr);
        pool.registerAddress(addressRegistrationData);

        // Owner disables screening entirely.
        pool.setScreener(IScreener(address(0)));

        vm.expectEmit(true, true, false, false);
        emit IPool.RegisterAddress(
            senderAddr,
            fixture.sender.rootAddress,
            0,
            shieldedAddress
        );
        vm.prank(senderAddr);
        pool.registerAddress(addressRegistrationData);
    }

    /// @notice A non-sanctioned caller registers normally even after another
    /// address has been flagged, proving the screening check is caller-scoped.
    function test_registerSucceedsWhenSenderNotSanctioned() external {
        screener.setSanctioned(SANCTIONED_ADDRESS, true);

        vm.expectEmit(true, true, false, false);
        emit IPool.RegisterAddress(
            senderAddr,
            fixture.sender.rootAddress,
            0,
            shieldedAddress
        );
        vm.prank(senderAddr);
        pool.registerAddress(addressRegistrationData);
    }

    //////////////////////////////////////////////////////
    /// Mainnet Fork Tests                          //////
    //////////////////////////////////////////////////////

    /// @notice Fork test against the live Chainalysis sanctions oracle on
    /// Ethereum mainnet. Verifies that the real `Screener` flags a known
    /// sanctioned address and that wiring it into the Pool blocks registration.
    /// @dev Run with a mainnet fork, e.g.
    ///      `forge test --fork-url $RPC_MAINNET --match-test test_fork_mainnetSanctionedAddressBlocksRegistration`
    function test_fork_mainnetSanctionedAddressBlocksRegistration() external {
        if (block.chainid != ETH_MAINNET) {
            vm.skip(true);
            return;
        }

        Screener realScreener = new Screener(MAINNET_SANCTIONS_LIST);

        // The live oracle flags the sanctioned address...
        assertTrue(
            realScreener.isSanctioned(SANCTIONED_ADDRESS),
            "expected address to be sanctioned on mainnet"
        );
        // ...but not an arbitrary fresh address.
        assertFalse(
            realScreener.isSanctioned(makeAddr("cleanAddress")),
            "did not expect random address to be sanctioned"
        );

        // Swap the mock for the real screener and confirm registration is blocked.
        pool.setScreener(IScreener(address(realScreener)));

        vm.expectRevert(
            abi.encodeWithSelector(
                IScreener.SanctionedAddress.selector,
                SANCTIONED_ADDRESS
            )
        );
        vm.prank(SANCTIONED_ADDRESS);
        pool.registerAddress(addressRegistrationData);
    }
}
