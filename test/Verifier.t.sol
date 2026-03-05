// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierTransact23} from "src/verifiers/VerifierTransact23.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {VerifierTreeUpdate} from "src/verifiers/VerifierTreeUpdate.sol";
import {ShieldedTransaction, ShieldedTransactionType} from "src/libraries/ShieldedTransaction.sol";
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
            address(vTreeUpdate)
        );
    }

    function test_getVerifierId() public view {
        uint256 id = _verifier.getTransactionVerifierId(2, 2);
        assertEq(id, 22);
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

    function test_revert_addVerifier_notOwner() public {
        TransactionVerifierInfo memory newVerifier = TransactionVerifierInfo({
            id: 23,
            addr: address(vt23),
            selector: vt23.verifyProof.selector
        });

        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        _verifier.addTransactionVerifier(newVerifier);
    }

    function test_revert_removeVerifier_notOwner() public {
        address nonOwner = address(0x123);
        vm.prank(nonOwner);
        vm.expectRevert();
        _verifier.removeTransactionVerifier(21);
    }
}
