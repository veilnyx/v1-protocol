// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {IVerifier} from "src/interfaces/IVerifier.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierTransact23} from "src/verifiers/VerifierTransact23.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransactionLogic.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";

contract VerifierTest is BaseTest {
    Verifier internal _verifier;
    VerifierTransact21 internal vt21;
    VerifierTransact22 internal vt22;
    VerifierTransact23 internal vt23;
    VerifierRegister internal vRegister;
    VerifierTreeUpdate internal vTreeUpdate;

    function setUp() public {
        vt21 = new VerifierTransact21();
        vt22 = new VerifierTransact22();
        vt23 = new VerifierTransact23();
        vRegister = new VerifierRegister();
        vTreeUpdate = new VerifierTreeUpdate();

        TransactionVerifierInfo[] memory vInfos = new TransactionVerifierInfo[](
            2
        );
        vInfos[0] = TransactionVerifierInfo({
            id: 21,
            addr: address(vt21),
            selector: vt21.verifyProof.selector
        });
        vInfos[1] = TransactionVerifierInfo({
            id: 22,
            addr: address(vt22),
            selector: vt22.verifyProof.selector
        });

        _verifier = new Verifier(
            vInfos,
            address(vRegister),
            address(vTreeUpdate),
            address(this)
        );
    }

    function test_getVerifierId() public view {
        uint256 id = _verifier.getTransactionVerifierId(2, 2);
        assertEq(id, 22);

        uint256 id2 = _verifier.getTransactionVerifierId(10, 10);
        assertEq(id2, 1010);

        uint256 id3 = _verifier.getTransactionVerifierId(123, 45);
        assertEq(id3, 12345);

        uint16 id4 = _verifier.getTransactionVerifierId(1, 0);
        assertEq(id4, 10);

        // Every deployed shape stays on its existing id.
        assertEq(_verifier.getTransactionVerifierId(2, 1), 21);
        assertEq(_verifier.getTransactionVerifierId(2, 3), 23);
        assertEq(_verifier.getTransactionVerifierId(4, 2), 42);
        assertEq(_verifier.getTransactionVerifierId(4, 4), 44);
        assertEq(_verifier.getTransactionVerifierId(8, 2), 82);
        assertEq(_verifier.getTransactionVerifierId(8, 4), 84);
    }

    /// Colliding circuit shapes intentionally share a registry slot. Adding a
    /// second verifier for that slot is rejected by addTransactionVerifier.
    function test_getVerifierIdAllowsMultiDigitCollision() public {
        uint16 multiDigitOutputsId = _verifier.getTransactionVerifierId(2, 10);
        uint16 multiDigitInputsId = _verifier.getTransactionVerifierId(21, 0);

        assertEq(multiDigitOutputsId, 210);
        assertEq(multiDigitInputsId, 210);

        _verifier.addTransactionVerifier(
            TransactionVerifierInfo({
                id: multiDigitOutputsId,
                addr: address(vt23),
                selector: vt23.verifyProof.selector
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Verifier.VerifierAlreadyExists.selector,
                multiDigitInputsId
            )
        );
        _verifier.addTransactionVerifier(
            TransactionVerifierInfo({
                id: multiDigitInputsId,
                addr: address(vt22),
                selector: vt22.verifyProof.selector
            })
        );
    }

    function test_getVerifierIdRevertsOnUint16Overflow() public {
        // nOuts=0 is treated as one digit, so verifierID = nIns * 10.
        // 65536 > type(uint16).max (65535)
        vm.expectRevert(
            abi.encodeWithSelector(
                IVerifier.VerifierIdOverflow.selector,
                uint256(655360)
            )
        );
        _verifier.getTransactionVerifierId(65536, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IVerifier.VerifierIdOverflow.selector,
                uint256(65546)
            )
        );
        _verifier.getTransactionVerifierId(6554, 6);
    }

    function test_getVerifierIdRevertsWhenNInsZero() public {
        // nIns=0, nOuts=6 → noOfDigits=1, verifierID = 0*10 + 6 = 6
        vm.expectRevert(
            abi.encodeWithSelector(
                IVerifier.BadArguments.selector,
                uint256(0),
                uint256(6)
            )
        );
        _verifier.getTransactionVerifierId(0, 6);
    }

    function test_addTransactionVerifier() public {
        TransactionVerifierInfo memory newVerifier = TransactionVerifierInfo({
            id: 23,
            addr: address(vt23),
            selector: vt23.verifyProof.selector
        });

        vm.expectEmit(true, false, false, true);
        emit Verifier.TransactionVerifierAdded(
            23,
            vt23.verifyProof.selector,
            address(vt23)
        );

        _verifier.addTransactionVerifier(newVerifier);

        TransactionVerifierInfo memory added = _verifier.getTransactionVerifier(
            23
        );
        assertEq(added.id, 23);
        assertEq(added.addr, address(vt23));
        assertEq(added.selector, vt23.verifyProof.selector);
    }

    function test_addTransactionVerifiers_batch() public {
        VerifierTransact23 vt23_2 = new VerifierTransact23();

        TransactionVerifierInfo[]
            memory newVerifiers = new TransactionVerifierInfo[](2);
        newVerifiers[0] = TransactionVerifierInfo({
            id: 23,
            addr: address(vt23),
            selector: vt23.verifyProof.selector
        });
        newVerifiers[1] = TransactionVerifierInfo({
            id: 24,
            addr: address(vt23_2),
            selector: vt23_2.verifyProof.selector
        });

        _verifier.addTransactionVerifiers(newVerifiers);

        TransactionVerifierInfo memory added23 = _verifier
            .getTransactionVerifier(23);
        assertEq(added23.id, 23);
        assertEq(added23.addr, address(vt23));

        TransactionVerifierInfo memory added24 = _verifier
            .getTransactionVerifier(24);
        assertEq(added24.id, 24);
        assertEq(added24.addr, address(vt23_2));
    }

    function test_removeTransactionVerifier() public {
        vm.expectEmit(true, false, false, false);
        emit Verifier.TransactionVerifierRemoved(21);

        _verifier.removeTransactionVerifier(21);

        TransactionVerifierInfo memory removed = _verifier
            .getTransactionVerifier(21);
        assertEq(removed.addr, address(0));
    }

    function test_revert_addVerifier_zeroAddress() public {
        TransactionVerifierInfo memory badVerifier = TransactionVerifierInfo({
            id: 23,
            addr: address(0),
            selector: bytes4(0)
        });

        vm.expectRevert(Verifier.ZeroAddress.selector);
        _verifier.addTransactionVerifier(badVerifier);
    }

    function test_revert_addVerifier_alreadyExists() public {
        TransactionVerifierInfo memory duplicateVerifier = TransactionVerifierInfo({
            id: 21, // Already exists
            addr: address(vt23),
            selector: vt23.verifyProof.selector
        });

        vm.expectRevert(
            abi.encodeWithSelector(Verifier.VerifierAlreadyExists.selector, 21)
        );
        _verifier.addTransactionVerifier(duplicateVerifier);
    }

    function test_revert_removeVerifier_notFound() public {
        vm.expectRevert("Verifier: verifier not found");
        _verifier.removeTransactionVerifier(99); // Doesn't exist
    }

    function test_revert_addVerifier_notVerifierManager() public {
        TransactionVerifierInfo memory newVerifier = TransactionVerifierInfo({
            id: 23,
            addr: address(vt23),
            selector: vt23.verifyProof.selector
        });

        address nonManager = address(0x123);
        vm.prank(nonManager);
        vm.expectRevert(Verifier.NotVerifierManager.selector);
        _verifier.addTransactionVerifier(newVerifier);
    }

    function test_revert_removeVerifier_notVerifierManager() public {
        address nonManager = address(0x123);
        vm.prank(nonManager);
        vm.expectRevert(Verifier.NotVerifierManager.selector);
        _verifier.removeTransactionVerifier(21);
    }

    // ── Verifier Manager Role ────────────────────────────────────────────────

    function test_verifierManager_setAtConstruction() public view {
        assertEq(_verifier.verifierManager(), address(this));
    }

    function test_setVerifierManager() public {
        address newManager = address(0xBEEF);

        vm.expectEmit(true, true, false, false);
        emit Verifier.VerifierManagerUpdated(address(this), newManager);

        _verifier.setVerifierManager(newManager);
        assertEq(_verifier.verifierManager(), newManager);
    }

    function test_revert_setVerifierManager_notOwner() public {
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        _verifier.setVerifierManager(address(0xBEEF));
    }

    function test_revert_setVerifierManager_zeroAddress() public {
        vm.expectRevert(Verifier.ZeroAddress.selector);
        _verifier.setVerifierManager(address(0));
    }

    function test_newManagerCanAddVerifier() public {
        address newManager = address(0xBEEF);
        _verifier.setVerifierManager(newManager);

        TransactionVerifierInfo memory newVerifier = TransactionVerifierInfo({
            id: 23,
            addr: address(vt23),
            selector: vt23.verifyProof.selector
        });

        vm.prank(newManager);
        _verifier.addTransactionVerifier(newVerifier);

        assertEq(_verifier.getTransactionVerifier(23).addr, address(vt23));
    }

    function test_previousManagerCannotActAfterTransfer() public {
        address newManager = address(0xBEEF);
        _verifier.setVerifierManager(newManager);

        // address(this) was the old manager — should now be rejected
        TransactionVerifierInfo memory newVerifier = TransactionVerifierInfo({
            id: 23,
            addr: address(vt23),
            selector: vt23.verifyProof.selector
        });

        vm.expectRevert(Verifier.NotVerifierManager.selector);
        _verifier.addTransactionVerifier(newVerifier);
    }

    function test_verifierManager_canUpdateTreeUpdateVerifier() public {
        VerifierTreeUpdate newTreeUpdate = new VerifierTreeUpdate();

        vm.expectEmit(true, false, false, false);
        emit Verifier.TreeUpdateVerifierUpdated(address(newTreeUpdate));

        _verifier.updateTreeUpdateVerifier(address(newTreeUpdate));
    }

    function test_revert_updateTreeUpdateVerifier_notVerifierManager() public {
        VerifierTreeUpdate newTreeUpdate = new VerifierTreeUpdate();

        vm.prank(address(0x123));
        vm.expectRevert(Verifier.NotVerifierManager.selector);
        _verifier.updateTreeUpdateVerifier(address(newTreeUpdate));
    }

    function test_verifierManager_canUpdateAddressVerifier() public {
        VerifierRegister newRegister = new VerifierRegister();

        vm.expectEmit(true, false, false, false);
        emit Verifier.AddressVerifierUpdated(address(newRegister));

        _verifier.updateAddressVerifier(address(newRegister));
    }

    function test_revert_updateAddressVerifier_notVerifierManager() public {
        VerifierRegister newRegister = new VerifierRegister();

        vm.prank(address(0x123));
        vm.expectRevert(Verifier.NotVerifierManager.selector);
        _verifier.updateAddressVerifier(address(newRegister));
    }
}
