// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolPauserTest is PoolTest {
    address internal owner;
    address internal pauser;
    address internal stranger;

    function setUp() public {
        _setUp();
        owner = address(this); // PoolBaseTest deploys pool with address(this) as owner
        pauser = makeAddr("pauser");
        stranger = makeAddr("stranger");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Initial state
    // ─────────────────────────────────────────────────────────────────────────

    function test_pauserIsZeroByDefault() public view {
        assertEq(pool.pauser(), address(0));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // setPauser
    // ─────────────────────────────────────────────────────────────────────────

    function test_ownerCanSetPauser() public {
        vm.expectEmit(true, true, false, false);
        emit IPool.PauserUpdated(address(0), pauser);

        pool.setPauser(pauser);

        assertEq(pool.pauser(), pauser);
    }

    function test_ownerCanRevokePauser() public {
        pool.setPauser(pauser);

        vm.expectEmit(true, true, false, false);
        emit IPool.PauserUpdated(pauser, address(0));

        pool.setPauser(address(0));

        assertEq(pool.pauser(), address(0));
    }

    function test_revert_setPauser_notOwner() public {
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                stranger
            )
        );
        pool.setPauser(pauser);
    }

    function test_revert_setPauser_notOwner_byPauser() public {
        pool.setPauser(pauser);

        vm.prank(pauser);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                pauser
            )
        );
        pool.setPauser(stranger);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // pause — no dedicated pauser (pauser == address(0))
    // ─────────────────────────────────────────────────────────────────────────

    function test_ownerCanPauseWhenNoPauserSet() public {
        // owner is address(this), no prank needed
        pool.pause();
        assertTrue(pool.paused());
    }

    function test_revert_pause_strangerWhenNoPauserSet() public {
        vm.prank(stranger);
        vm.expectRevert(IPool.NotPauser.selector);
        pool.pause();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // pause — with a dedicated pauser
    // ─────────────────────────────────────────────────────────────────────────

    function test_pauserCanPause() public {
        pool.setPauser(pauser);

        vm.prank(pauser);
        pool.pause();

        assertTrue(pool.paused());
    }

    function test_ownerCanStillPauseAfterPauserSet() public {
        pool.setPauser(pauser);

        // owner retains pause rights even when a dedicated pauser is set
        pool.pause();
        assertTrue(pool.paused());
    }

    function test_revert_pause_strangerWhenPauserSet() public {
        pool.setPauser(pauser);

        vm.prank(stranger);
        vm.expectRevert(IPool.NotPauser.selector);
        pool.pause();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // unpause — always owner only
    // ─────────────────────────────────────────────────────────────────────────

    function test_ownerCanUnpause() public {
        pool.pause();
        pool.unpause();
        assertFalse(pool.paused());
    }

    function test_ownerCanUnpauseAfterPauserSet() public {
        pool.setPauser(pauser);
        vm.prank(pauser);
        pool.pause();

        // owner, not the pauser, unpauses
        pool.unpause();
        assertFalse(pool.paused());
    }

    function test_revert_unpause_byPauser() public {
        pool.setPauser(pauser);
        vm.prank(pauser);
        pool.pause();

        vm.prank(pauser);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                pauser
            )
        );
        pool.unpause();
    }

    function test_revert_unpause_byStranger() public {
        pool.pause();

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                stranger
            )
        );
        pool.unpause();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // owner regains pause rights after revoking pauser
    // ─────────────────────────────────────────────────────────────────────────

    function test_ownerRegainsPauseAfterRevoke() public {
        pool.setPauser(pauser);
        pool.setPauser(address(0)); // revoke

        // owner should be able to pause again
        pool.pause();
        assertTrue(pool.paused());
    }

    function test_revokedPauserCannotPause() public {
        pool.setPauser(pauser);
        pool.setPauser(address(0)); // revoke

        vm.prank(pauser);
        vm.expectRevert(IPool.NotPauser.selector);
        pool.pause();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // paused state gates protocol operations
    // ─────────────────────────────────────────────────────────────────────────

    function test_pauseBlocksTransact() public {
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        pool.pause();

        vm.expectRevert();
        pool.transact(stx);
    }
}
