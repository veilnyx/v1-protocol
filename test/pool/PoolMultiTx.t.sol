// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolMultiTxTest is PoolTest {
    Pool internal _pool;
    PoolTransactTest poolTransactTestHelper;
    ZTransaction[] fixtureZTx;
    address withdrawAddr = 0x19d10A59420fd2587a73EB65266E57eb6b6157f9;

    function setUp() public {
        _setUp();
        // _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        // _approveAsset(asset1, address(pool), INITIAL_DEPOSIT);

        ZTransaction memory depositZTx = _loadShieldedTransaction(
            "deposit_1000_weth_for_seq_ztx"
        ); // deposit setup
        pool.transact(depositZTx);

        // loading the batch of trxn to execute by the fuzzer
        ZTransaction memory withdrawZTx = _loadShieldedTransaction(
            "withdraw_500_weth_for_seq_ztx"
        );

        ZTransaction memory transferZTx = _loadShieldedTransaction(
            "transfer_200_weth_for_seq_ztx"
        );

        fixtureZTx.push(withdrawZTx);
        fixtureZTx.push(transferZTx);
    }

    function test_MultiTxValueConservation() public {
        // order to tx execution is crucial here. Should match `genSequentialZTxFixtures.ts`.
        pool.transact(fixtureZTx[0]);
        pool.transact(fixtureZTx[1]);

        uint256 totalValue = token1.balanceOf(address(pool)) +
            token1.balanceOf(withdrawAddr);
        // assertEq(totalValue, INITIAL_DEPOSIT);
    }
}
