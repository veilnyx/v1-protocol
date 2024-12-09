// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {ShieldedTransaction, ShieldedTransactionLogic} from "src/libraries/ShieldedTransaction.sol";
import {console2} from "forge-std/console2.sol";

contract PoolNonAtomicTxTest is PoolTest {
    using ShieldedTransactionLogic for ShieldedTransaction;

    uint256 constant DEPOSIT_AMOUNT = 2 ether;

    function setUp() public {
        PoolTest._setUp();
        deal(address(token1), address(this), DEPOSIT_AMOUNT);

        IERC20(address(token1)).approve(address(pool), DEPOSIT_AMOUNT);
        ShieldedTransaction memory stxDeposit = _loadShieldedTransaction(
            "deposit_2_weth"
        );
        pool.transact(stxDeposit);
        _processCommitmentTreeQueue();
    }

    function test_nonAtomicTx_withoutAnyRefundNotes() public {
        ShieldedTransaction memory stxNonAtomic = _loadShieldedTransaction(
            "use_2_weth"
        );
        address dummyAdp = 0xbF71c5Ae43827387dAAF7358acAB5C81642b74b8; // used in `use_2_weth` fixture
        pool.addAdaptorSupport((dummyAdp), true);

        (, , , , uint32 nextLeafIndex) = pool.getCommitmentTreeState();

        bytes memory assetsMemo = abi.encodePacked(stxNonAtomic.pubAssets);

        pool.transact(stxNonAtomic);
    }
}
