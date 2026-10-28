// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {PoolBaseTest} from "test/fixtures/PoolBaseTest.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {AssetType, AssetInitParams} from "src/libraries/AssetLogic.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {ShieldedAddressRegistrationData} from "src/libraries/ShieldedAddressLogic.sol";
import {TreeUpdateData, QueuedMerkleTree, QueuedMerkleTreeLogic} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {FIELD_SIZE, COMMITMENT_TREE_DEPTH} from "src/base/Constants.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {MockAggregatorV3} from "test/mocks/MockAggregatorV3.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {DevVerifierTransact21} from "./DevVerifierTransact21.sol";
import {DevVerifierTransact22} from "./DevVerifierTransact22.sol";
import {DevVerifierTransact23} from "./DevVerifierTransact23.sol";
import {DevVerifierRegister} from "./DevVerifierRegister.sol";
import {DevVerifierTreeUpdate} from "./DevVerifierTreeUpdate.sol";

/// Regression tests for the non-canonical field element findings (2026-09 audit).
///
/// Nullifiers, commitments and notesMemo reach the transact circuit only through
/// alpha (sha256 of the raw words) and gamma (mulmod p), so the proof verifies for
/// x and x + p alike. The pool must therefore reject any word >= FIELD_SIZE itself.
///
/// The fixtures are real Groth16 proofs made with dev keys (v1-circuits 7270065); only the
/// snarkjs verifier constants differ from production. The `_aliased` fixtures are the
/// attack proofs that were accepted before the fix.
contract FieldCanonicalityTest is PoolBaseTest {
    address constant BEEF = 0x000000000000000000000000000000000000bEEF;
    MockERC20 weth;

    function setUp() public {
        PoolBaseTest._setUp();

        // dev-key verifiers behind the production router
        TransactionVerifierInfo[] memory v = new TransactionVerifierInfo[](3);
        DevVerifierTransact21 v21 = new DevVerifierTransact21();
        DevVerifierTransact22 v22 = new DevVerifierTransact22();
        DevVerifierTransact23 v23 = new DevVerifierTransact23();
        v[0] = TransactionVerifierInfo(21, v21.verifyProof.selector, address(v21));
        v[1] = TransactionVerifierInfo(22, v22.verifyProof.selector, address(v22));
        v[2] = TransactionVerifierInfo(23, v23.verifyProof.selector, address(v23));
        Verifier router = new Verifier(
            v,
            address(new DevVerifierRegister()),
            address(new DevVerifierTreeUpdate()),
            address(this)
        );
        pool.mock_verifier(address(router));

        weth = token1; // first ERC20 => asset id 65537
        AssetInitParams[] memory a = new AssetInitParams[](1);
        a[0] = AssetInitParams({
            assetAddress: address(weth),
            precision: 18,
            usdPriceFeed: AggregatorV3Interface(address(new MockAggregatorV3(1e8, 8)))
        });
        pool.addAssets(AssetType.ERC20, a);
        assertEq(pool.getAsset(address(weth)).id, 65537);

        pool.registerRevoker(fixture.revokerPublicKey, fixture.encryptionPublicKey, "");

        ShieldedAddressRegistrationData memory reg = _loadShieldedAddressRegistrationData("poc_register");
        reg.signature = _getRegisterAddressSignature(fixture.registrant.privateKey, reg.shieldedAddress);
        pool.registerAddress(reg);

        weth.mint(address(this), 1_000 ether);
        weth.approve(address(pool), type(uint256).max);
    }

    /// CRITICAL (fixed): publishing n + p as the nullifier spent the same note twice.
    function test_aliasedNullifierRejected() public {
        pool.transact(_loadShieldedTransaction("poc_deposit"));
        pool.updateCommitmentTree(_loadTreeUpdateData("poc_tree_update"));
        weth.mint(address(pool), 400 ether);

        ShieldedTransaction memory w1 = _loadShieldedTransaction("poc_withdraw");
        ShieldedTransaction memory w2 = _loadShieldedTransaction("poc_withdraw_aliased");
        assertEq(w2.nullifiers[0], w1.nullifiers[0] + FIELD_SIZE, "w2 publishes n + p");

        pool.transact(w1);
        uint256 paidOnce = weth.balanceOf(BEEF);
        assertEq(paidOnce, 100 ether - (100 ether * 5) / 10000);

        vm.expectRevert(abi.encodeWithSelector(IPool.DoubleSpend.selector, w1.nullifiers[0]));
        pool.transact(w1);

        vm.expectRevert(abi.encodeWithSelector(IPool.NonCanonicalFieldElement.selector, w2.nullifiers[0]));
        pool.transact(w2);

        assertEq(weth.balanceOf(BEEF), paidOnce, "paid out exactly once");
    }

    /// HIGH (fixed): a commitment published as c + p was queued raw and froze the tree queue.
    function test_aliasedCommitmentRejected() public {
        ShieldedTransaction memory d = _loadShieldedTransaction("poc_deposit_aliased_cm");
        assertGe(d.commitments[0], FIELD_SIZE);
        vm.expectRevert(abi.encodeWithSelector(IPool.NonCanonicalFieldElement.selector, d.commitments[0]));
        pool.transact(d);

        (uint32 startIdx, uint32 endIdx, , , ) = pool.getQueueRawState();
        assertEq(endIdx - startIdx, 0, "nothing queued");

        // the tree keeps working for honest users
        pool.transact(_loadShieldedTransaction("poc_deposit"));
        pool.updateCommitmentTree(_loadTreeUpdateData("poc_tree_update"));
    }

    /// MEDIUM (fixed): a notesMemo word >= p decrypts to garbage for the revoker (the circuit
    /// only binds it mod p). The canonicality check runs before the proof, so no fixture is needed.
    function test_nonCanonicalMemoWordRejected() public {
        ShieldedTransaction memory d = _loadShieldedTransaction("poc_deposit");
        uint256 word;
        bytes memory memo = d.notesMemo;
        assembly {
            word := mload(add(memo, 0x20))
        }
        uint256 aliased = word + FIELD_SIZE;
        assembly {
            mstore(add(memo, 0x20), aliased)
        }
        vm.expectRevert(abi.encodeWithSelector(IPool.NonCanonicalFieldElement.selector, aliased));
        pool.transact(d);
    }

    /// Defence in depth: QueuedMerkleTreeLogic.queueLeaves rejects a leaf >= p by itself.
    function test_queueLeavesRejectsNonCanonicalLeaf() public {
        QueueHarness h = new QueueHarness();
        uint256[] memory leaves = new uint256[](2);
        leaves[0] = 1;
        leaves[1] = FIELD_SIZE;
        vm.expectRevert(abi.encodeWithSelector(QueuedMerkleTreeLogic.InvalidLeaf.selector, FIELD_SIZE));
        h.queue(leaves);
        leaves[1] = FIELD_SIZE - 1;
        h.queue(leaves);
    }

    function test_control_honestUpdateWorks() public {
        pool.transact(_loadShieldedTransaction("poc_deposit"));
        pool.updateCommitmentTree(_loadTreeUpdateData("poc_tree_update"));
    }

    /// MEDIUM (fixed): a batchSize = 0 update is a provable no-op whose proof replays verbatim;
    /// 100 replays evicted every historic root and invalidated in-flight transactions.
    function test_zeroBatchUpdateRejected() public {
        (, , uint256 r0, , ) = pool.getCommitmentTreeState();
        pool.transact(_loadShieldedTransaction("poc_deposit"));
        pool.updateCommitmentTree(_loadTreeUpdateData("poc_tree_update"));

        TreeUpdateData memory noop = _loadTreeUpdateData("poc_tree_update_noop");
        assertEq(noop.batchSize, 0);
        vm.expectRevert(QueuedMerkleTreeLogic.InvalidBatchSize.selector);
        pool.updateCommitmentTree(noop);

        assertTrue(pool.isKnownCommitmentTreeRoot(r0), "r0 still in history");
        pool.transact(_loadShieldedTransaction("poc_deposit_victim_r0"));
    }

    function test_control_victimWorksWithoutAttack() public {
        pool.transact(_loadShieldedTransaction("poc_deposit"));
        pool.updateCommitmentTree(_loadTreeUpdateData("poc_tree_update"));
        pool.transact(_loadShieldedTransaction("poc_deposit_victim_r0"));
    }
}

contract QueueHarness {
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    QueuedMerkleTree internal tree;

    function queue(uint256[] calldata leaves) external {
        tree.queueLeaves(leaves);
    }
}
