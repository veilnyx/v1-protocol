// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolTransactTest is Test {
    ZTransaction ztx;
    uint256 initialDeposit;
    MockERC20 public token1;
    MockERC20 public token2;
    Pool public pool;

    constructor(ZTransaction memory ztx_, uint256 initialDeposit_, MockERC20 token1_, MockERC20 token2_, Pool pool_) {
        ztx = ztx_;
        initialDeposit = initialDeposit_;
        token1 = token1_;
        token2 = token2_;
        pool = pool_;
        
        MockERC20(token1).approve(address(pool), initialDeposit);
        MockERC20(token2).approve(address(pool), initialDeposit);
    }

    function makeInitialDeposit(ZTransaction memory depositZTx) public {
        pool.transact(depositZTx);
    }

    function updateZTxToExecute(ZTransaction memory newZTx) public {
        ztx = newZTx;
    }

    function test_nullifiersMarked() public {
        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(ztx.nullifiers[i]);
        }

        pool.transact(ztx);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        }
    }

    function test_leafAddedToCommitmentTree() external {
        uint256 commitmentTreeRootBeforeDeposit = pool.getLastRoot();
        uint256 commitmentTreeCurrentRootIndexBeforeDeposit = pool
            .getCurrentRootIndex();

        pool.transact(ztx);

        uint256 commitmentTreeRootAfterDeposit = pool.getLastRoot();
        uint256 commitmentTreeCurrentRootIndexAfterDeposit = pool
            .getCurrentRootIndex();

        assert(
            commitmentTreeRootBeforeDeposit != commitmentTreeRootAfterDeposit
        );
        assert(
            commitmentTreeCurrentRootIndexBeforeDeposit <
                commitmentTreeCurrentRootIndexAfterDeposit
        );
    }

    function test_Annoucements() external {
        uint256 nextIndex = pool.getNextLeafIndex();
        console.log("Leaf commitment for deposit:", ztx.commitments.length);

        for (uint256 a = 0; a < ztx.commitments.length; a++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.Announcement(
                nextIndex,
                ztx.commitments[a],
                ztx.outMemos[a]
            );
            nextIndex++;
        }
        pool.transact(ztx);
    }

    function test_InputNotesMemoEvent() external {
        vm.expectEmit(true, true, false, true);
        emit IPool.InputNoteMemos(ztx.inMemos);
        pool.transact(ztx);
    }
}
