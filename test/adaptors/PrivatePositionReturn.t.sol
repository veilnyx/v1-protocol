// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTreeLogic.sol";
import {COMMITMENT_TREE_DEPTH} from "src/base/Constants.sol";

/// @title The return leg of a private position
/// @notice Closes the last untested step. A burner deposits its proceeds and the
///         notes are owned by the USER'S main shielded account — no burner
///         registration, no internal transfer, one public transaction.
///
///         The whole design rests on one property of the Pool: `transact` never
///         binds `msg.sender` on a deposit, it only sanctions-screens it. So a
///         proof built for the user's account can be submitted by ANY address
///         holding the tokens. That is what lets the burner be the submitter
///         while the value lands with the user, and it is why the burner needs
///         no shielded account of its own — registering one would write a public
///         EOA -> rootAddress mapping and undo the privacy the design exists for.
contract PrivatePositionReturnTest is PoolTest {
    /// The burner from the testnet lifecycle drill, derived from a test seed.
    address constant BURNER = 0xFa214a7EBA274116D38Abcb01D8A1AA31e09F5cC;

    function setUp() external {
        PoolTest._setUp();
    }

    /// @dev The fixture generators share one commitment tree, so this proof was
    ///      built against a root reflecting every insertion before it. A DEPOSIT
    ///      spends no notes and carries no nullifiers, so the root is only a
    ///      known-root check — forcing the tree to it isolates the property under
    ///      test instead of replaying four unrelated fixtures. The transact proof
    ///      itself is real and verified by the real verifier; only the
    ///      tree-update verifier is mocked, as PoolTest already does.
    function _adoptRoot(uint256 root) internal {
        (uint32 sIdx, uint32 eIdx, , , ) = pool.getQueueRawState();
        uint256[COMMITMENT_TREE_DEPTH] memory subtrees;
        _mockVerifierResult(true);
        pool.updateCommitmentTree(
            TreeUpdateData({
                newRoot: root,
                batchSize: eIdx - sIdx,
                newLevelSubtrees: subtrees,
                proof: bytes("")
            })
        );
        _mockVerifierReset();
    }

    function test_burnerReturnsProceedsToTheUsersShieldedAccount() public {
        uint256 proceeds = 1493.52e6; // PnL-shaped, as a real return is
        IERC20 usdc = IERC20(asset2.assetAddress);

        // The burner holds the proceeds: in production it closed the position,
        // moved perp -> spot, and bridged home. It has never registered a
        // shielded address and never will.
        _mintAsset(asset2, BURNER, proceeds);
        assertEq(usdc.balanceOf(BURNER), proceeds, "burner holds the proceeds");

        uint256 poolBefore = usdc.balanceOf(address(pool));
        (, , , , uint32 leavesBefore) = pool.getCommitmentTreeState();

        // The proof was built with the USER'S account context, so its output
        // notes are owned by the user. The BURNER submits it.
        ShieldedTransaction memory stx = _loadShieldedTransaction("private_position_return");
        _adoptRoot(stx.commitmentTreeRoot);

        vm.startPrank(BURNER);
        usdc.approve(address(pool), proceeds);
        pool.transact(stx);
        vm.stopPrank();

        // The value moved from the burner into the pool...
        assertEq(usdc.balanceOf(BURNER), 0, "burner is emptied");
        assertEq(usdc.balanceOf(address(pool)) - poolBefore, proceeds, "pool received the proceeds");

        // ...and a commitment was queued, which is the user's note.
        (uint32 startIdx, uint32 endIdx, , , ) = pool.getQueueRawState();
        assertGt(endIdx - startIdx, 0, "an output note was committed");

        _processCommitmentTreeQueue();
        (, , , , uint32 leavesAfter) = pool.getCommitmentTreeState();
        assertGt(leavesAfter, leavesBefore, "the note is in the commitment tree");

        console2.log("burner submitted   :", BURNER);
        console2.log("proceeds returned  :", proceeds);
        console2.log("notes committed    :", leavesAfter - leavesBefore);
    }

    /// @dev The property the whole return path depends on, isolated: a deposit
    ///      proof does not bind its submitter. The SAME proof — built for the
    ///      user's account — is submitted here by an address with no connection
    ///      to the user or the burner, and it succeeds.
    ///
    ///      This is what lets the burner deposit without ever registering a
    ///      shielded address. If it ever stopped holding, the burner would need
    ///      its own registration, writing a PUBLIC EOA -> rootAddress mapping,
    ///      and the design would lose exactly the link it exists to hide.
    function test_aDepositProofDoesNotBindItsSubmitter() public {
        address stranger = address(0xBEEF);
        uint256 proceeds = 1493.52e6;

        ShieldedTransaction memory stx = _loadShieldedTransaction("private_position_return");
        _adoptRoot(stx.commitmentTreeRoot);

        _mintAsset(asset2, stranger, proceeds);
        vm.startPrank(stranger);
        IERC20(asset2.assetAddress).approve(address(pool), proceeds);
        pool.transact(stx);
        vm.stopPrank();

        assertEq(IERC20(asset2.assetAddress).balanceOf(stranger), 0, "stranger's tokens moved");
        (uint32 s_, uint32 e_, , , ) = pool.getQueueRawState();
        assertGt(e_ - s_, 0, "the user's note was committed by an unrelated submitter");
    }
}
