// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console2} from "forge-std/console2.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction, ShieldedTransactionLogic} from "src/libraries/ShieldedTransactionLogic.sol";
import {TreeUpdateData, QueuedMerkleTreeLogic} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddressLogic.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

/// Every confirmed attack from the audit, replayed against the fully live stack:
/// new circuits, new SDK-generated proofs, patched contracts, real deployment in setUp.
/// All of these succeeded before the fixes.
contract AuditAttacks is PoolTest {
    function setUp() public {
        _setUp();
    }


    /// These consume fixtures and verifiers generated locally from the current circuit
    /// revision (see v1-sdk tests/genProtocolFixtures.test.ts and `pnpm compile` in
    /// v1-circuits). They are inert against the committed production verifiers, so they
    /// arm only when that dev stack is in place:
    ///
    ///   AUDIT_DEV_ARTIFACTS=1 forge test --match-path 'test/Audit*.t.sol'
    ///
    /// After the real ceremony, regenerate the fixtures and drop this gate.
    function _requireDevArtifacts() internal {
        if (vm.envOr("AUDIT_DEV_ARTIFACTS", uint256(0)) == 0) {
            vm.skip(true);
        }
    }

    function _fund() internal {
        _mintAsset(asset1, address(this), 100000 ether);
        _approveAsset(asset1, address(pool), 100000 ether);
    }

    function _deposit() internal view returns (ShieldedTransaction memory) {
        return _loadShieldedTransaction("audit_deposit");
    }

    // ---------------------------------------------------------------- C-1 ----
    // Append the honest public signals INSIDE the proof blob. The ABI decoder
    // ignores trailing calldata, so pre-fix the verifier read the attacker's
    // signals and the Pool acted on entirely different data.

    function test_attack_C1_transact_forgedPublicSignals() public {
        _requireDevArtifacts();
        _fund();
        ShieldedTransaction memory stx = _deposit();
        stx.proof = bytes.concat(stx.proof, hex"deadbeef", new bytes(28));

        vm.expectRevert(bytes("Verifier: invalid proof length"));
        pool.transact(stx);
    }

    function test_attack_C1_treeUpdate_arbitraryRoot() public {
        _requireDevArtifacts();
        _fund();
        pool.transact(_deposit());

        TreeUpdateData memory upd = _loadTreeUpdateData("audit_tree_update");
        upd.proof = bytes.concat(upd.proof, new bytes(32));
        upd.newRoot = uint256(keccak256("attacker root"));

        vm.expectRevert(bytes("Verifier: invalid proof length"));
        pool.updateCommitmentTree(upd);
    }

    function test_attack_C1_register_forgedAddress() public {
        _requireDevArtifacts();
        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData(
            "register_sender"
        );
        reg.proof = bytes.concat(reg.proof, new bytes(32));
        // Use a different rootAddress so the duplicate-registration guard does not
        // short-circuit, and a real signature so ECDSA recovery does not either.
        bytes memory addr = reg.shieldedAddress;
        assembly {
            mstore(add(addr, 32), 0xBADC0DE)
        }
        reg.shieldedAddress = addr;
        (, uint256 pk) = makeAddrAndKey("attacker");
        reg.signature = _getRegisterAddressSignature(pk, addr);

        vm.expectRevert(bytes("Verifier: invalid proof length"));
        pool.registerAddress(reg);
    }

    // ---------------------------------------------------------------- H-1 ----
    // Overstating batchSize is honestly provable (ZERO_LEAF padding is a root
    // no-op) and drove queueStartIndex past queueEndIndex, bricking the pool.

    function test_attack_H1_overstatedBatchSizeBricksPool() public {
        _requireDevArtifacts();
        _fund();
        pool.transact(_deposit());

        TreeUpdateData memory upd = _loadTreeUpdateData("audit_tree_update");
        upd.batchSize = 10; // queue holds only the single deposit commitment

        vm.expectRevert(QueuedMerkleTreeLogic.InvalidBatchSize.selector);
        pool.updateCommitmentTree(upd);
    }

    // ---------------------------------------------------------------- L-2 ----
    // Trailing memo words were unauthenticated by the proof yet still emitted in
    // the Receipt, letting a relayer append arbitrary data to a user's memo.

    function test_attack_L2_appendedMemoTail() public {
        _requireDevArtifacts();
        _fund();
        ShieldedTransaction memory stx = _deposit();
        stx.notesMemo = bytes.concat(stx.notesMemo, bytes32(uint256(0xbad)));

        vm.expectRevert(bytes("Invalid notesMemo length"));
        pool.transact(stx);
    }

    // ---------------------------------------------------------------- H-2 ----
    // A low-order revoker key collapses every nullifier to
    // Poseidon(leafIndex, commitment, 0), computable from public chain data.

    function test_attack_H2_lowOrderRevokerKeyRejected() public {
        _requireDevArtifacts();
        uint256[2] memory identity = [uint256(0), uint256(1)];
        uint256[2] memory good = [
            10031262171927540148667355526369034398030886437092045105752248699557385197826,
            633281375905621697187330766174974863687049529291089048651929454608812697683
        ];

        vm.prank(pool.owner());
        vm.expectRevert(
            abi.encodeWithSelector(IPool.InvalidCurvePoint.selector, uint256(0), uint256(1))
        );
        pool.registerRevoker(identity, good, "");
    }

    function test_attack_H2_offCurveRevokerKeyRejected() public {
        _requireDevArtifacts();
        uint256[2] memory offCurve = [uint256(1), uint256(1)]; // not on BabyJubJub
        uint256[2] memory good = [
            10031262171927540148667355526369034398030886437092045105752248699557385197826,
            633281375905621697187330766174974863687049529291089048651929454608812697683
        ];

        vm.prank(pool.owner());
        vm.expectRevert(
            abi.encodeWithSelector(IPool.InvalidCurvePoint.selector, uint256(1), uint256(1))
        );
        pool.registerRevoker(offCurve, good, "");
    }

    // ------------------------------------------------------- double spend ----

    function test_attack_replayedTransactionRejected() public {
        _requireDevArtifacts();
        _fund();
        ShieldedTransaction memory stx = _deposit();
        pool.transact(stx);

        // Same nullifiers a second time.
        vm.expectRevert();
        pool.transact(stx);
    }

    // ----------------------------------------------------- unknown root ------

    function test_attack_unknownCommitmentTreeRootRejected() public {
        _requireDevArtifacts();
        _fund();
        ShieldedTransaction memory stx = _deposit();
        stx.commitmentTreeRoot = uint256(keccak256("not a real root"));

        vm.expectRevert();
        pool.transact(stx);
    }

    function test_attack_zeroAddressTreeRootRejected() public {
        _requireDevArtifacts();
        _fund();
        ShieldedTransaction memory stx = _deposit();
        stx.addressTreeRoot = 0;

        vm.expectRevert();
        pool.transact(stx);
    }
}
