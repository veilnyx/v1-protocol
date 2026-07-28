// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";

/// L-2: `_decomposeNotesMemo` consumes exactly 7 + 4*nOuts words. Trailing words
/// were never folded into alpha/gamma, so they were unauthenticated by the proof
/// while still being emitted verbatim in the Receipt event -- a relayer could
/// append arbitrary bytes to a user's memo without invalidating their proof.
contract AuditMemoTail is PoolTest {
    function setUp() public {
        _setUp();
    }

    function _fundAndApprove() internal {
        _mintAsset(asset1, address(this), 100000 ether);
        _mintAsset(asset2, address(this), 100000e6);
        _approveAsset(asset1, address(pool), 100000 ether);
        _approveAsset(asset2, address(pool), 100000e6);
    }

    /// Control: the untouched fixture is exactly 32 * (7 + 4*nOuts) and succeeds.
    function test_control_honestMemoAccepted() public {
        _fundAndApprove();
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        assertEq(
            stx.notesMemo.length,
            32 * (7 + 4 * stx.commitments.length),
            "fixture memo is not exactly sized"
        );

        pool.transact(stx);
    }

    function test_appendedMemoTailRejected() public {
        _fundAndApprove();
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );

        // Relayer appends one unauthenticated word to the memo.
        stx.notesMemo = bytes.concat(stx.notesMemo, bytes32(uint256(0xdeadbeef)));

        vm.expectRevert(bytes("Invalid notesMemo length"));
        pool.transact(stx);
    }
}
