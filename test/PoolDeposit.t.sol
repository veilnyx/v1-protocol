// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";

contract PoolDepositTest is PoolTest {
    ZTransaction ztx;
    uint256 constant INITIAL_DEPOSIT = 1000 ether;

    function setUp() public {
        _initFixture();
        _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        _mintAsset(asset2, address(this), INITIAL_DEPOSIT);
        _approveAsset(asset1, address(pool), INITIAL_DEPOSIT);
        _approveAsset(asset2, address(pool), INITIAL_DEPOSIT);

        ztx = _loadZTx("deposit_1000_weth_usdc");
    }

    function test_depositAssetBalances() public {
        uint256 balance1 = token1.balanceOf(address(pool));
        uint256 balance2 = token2.balanceOf(address(pool));

        pool.transact(ztx);

        assertEq(token1.balanceOf(address(pool)), balance1 + INITIAL_DEPOSIT);
        assertEq(token2.balanceOf(address(pool)), balance2 + 1000e6); // USDC is 6 decimals
    }

    function test_nullifiersMarkedPostDeposit() public {
        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(ztx.nullifiers[i]);
        }

        pool.transact(ztx);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        }
    }

    function test_leafAddedToCommitmentTreePostDeposit() external {
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

    function test_AnnoucementsOnDeposit() external {
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
