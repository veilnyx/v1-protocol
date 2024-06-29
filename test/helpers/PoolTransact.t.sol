// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolTransactTest is Test {
    ZTransaction ztx;
    uint256 initialDeposit;
    MockERC20 public token1;
    MockERC20 public token2;
    Pool public pool;

    constructor(
        ZTransaction memory ztx_,
        uint256 initialDeposit_,
        MockERC20 token1_,
        MockERC20 token2_,
        Pool pool_
    ) {
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
        for (uint256 i = ztx.nullifiers.length; i > 0; i--) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(ztx.nullifiers[i - 1]);
        }

        pool.transact(ztx);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        }
    }

    function test_leafAddedToCommitmentTree() external {
        uint256 nextLeafIndexBeforeDeposit = pool
            .getCommitmentTreeNextLeafIndex();
        uint256 rootBeforeDeposit = pool.getCommitmentTreeLastRoot();
        uint256 currentRootIndexBeforeDeposit = pool
            .getCommitmentTreeCurrentRootIndex();

        pool.transact(ztx);

        uint256 nextLeafIndexAfterDeposit = pool
            .getCommitmentTreeNextLeafIndex();
        uint256 rootAfterDeposit = pool.getCommitmentTreeLastRoot();
        uint256 currentRootIndexAfterDeposit = pool
            .getCommitmentTreeCurrentRootIndex();

        assert(nextLeafIndexBeforeDeposit < nextLeafIndexAfterDeposit);
        assert(rootBeforeDeposit != rootAfterDeposit);
        assert(currentRootIndexBeforeDeposit < currentRootIndexAfterDeposit);
    }

    function test_Annoucements() external {
        uint256 nextIndex = pool.getCommitmentTreeNextLeafIndex();
        console.log("Leaf commitment for deposit:", ztx.commitments.length);

        // for (uint256 a = 0; a < ztx.commitments.length; a++) {
        //     vm.expectEmit(true, true, true, true);
        //     emit IPool.Announcement(
        //         nextIndex,
        //         ztx.commitments[a],
        //         ztx.noteMemos[a]
        //     );
        //     nextIndex++;
        // }
        pool.transact(ztx);
    }

    // function test_InputNotesMemoEvent() external {
    //     vm.expectEmit(true, true, false, true);
    //     emit IPool.InputNoteMemos(ztx.inMemos);
    //     pool.transact(ztx);
    // }

    // function test_ComplianceMemo() external {
    //     vm.expectEmit(true, true, false, true);
    //     emit IPool.ComplianceMemo(ztx.complianceMemo);
    //     pool.transact(ztx);
    // }
}
