// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console2} from "forge-std/console2.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {TreeUpdateData, QueuedMerkleTreeLogic} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

/// Full on-chain exercise of the audited stack against proofs produced by the CURRENT
/// circuit revision and the CURRENT SDK, rather than the committed fixtures.
///
/// Fixtures come from v1-sdk `tests/genProtocolFixtures.test.ts`; the verifiers in
/// src/verifiers are the locally compiled dev-key builds. Both are throwaway. The point
/// is to prove circuits, SDK and contracts agree before the real ceremony.
///
/// Registration is exercised implicitly: PoolTest._setUp() registers the sender using
/// the regenerated 6-input register proof, so reaching any test here already proves the
/// register binding works end to end on chain.
contract AuditFullE2E is PoolTest {
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

    function test_e2e_depositThenTreeUpdate() public {
        _requireDevArtifacts();
        _fund();

        // ---- deposit, proved by the new transact circuit ----
        ShieldedTransaction memory stx = _loadShieldedTransaction("audit_deposit");
        uint256 before = MockERC20(asset1.assetAddress).balanceOf(address(pool));
        pool.transact(stx);
        uint256 aft = MockERC20(asset1.assetAddress).balanceOf(address(pool));

        assertGt(aft, before, "pool balance did not increase on deposit");
        console2.log("deposit accepted, pool delta:", aft - before);

        // ---- flush the queue with the proved tree update ----
        (, , uint256 rootBefore, , ) = pool.getCommitmentTreeState();
        TreeUpdateData memory upd = _loadTreeUpdateData("audit_tree_update");
        pool.updateCommitmentTree(upd);
        (, , uint256 rootAfter, , ) = pool.getCommitmentTreeState();

        assertTrue(rootAfter != rootBefore, "commitment tree root did not advance");
        assertEq(rootAfter, upd.newRoot, "root does not match the proved newRoot");
        console2.log("tree update accepted, new root:", rootAfter);
    }
}
