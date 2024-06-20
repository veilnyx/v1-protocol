// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {PoolTransactTest} from "test/helpers/PoolTransact.t.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract PoolMultiTxTest is PoolTest {
    Pool internal _pool;
    PoolTransactTest poolTransactTestHelper;
    ZTransaction[] fixtureZTx;
    address withdrawAddr = 0x19d10A59420fd2587a73EB65266E57eb6b6157f9;

    function setUp() public {
        _initFixture();
        _mintAsset(asset1, address(this), INITIAL_DEPOSIT);
        _approveAsset(asset1, address(pool), INITIAL_DEPOSIT);

        ZTransaction memory depositZTx = _loadZTx(
            "deposit_1000_weth_without_fee"
        ); // deposit setup
        pool.transact(depositZTx);

        // loading the batch of trxn to execute by the fuzzer
        ZTransaction memory transferZTx = _loadZTx(
            "transfer_200_weth_without_fee"
        );
        ZTransaction memory withdrawZTx = _loadZTx(
            "withdraw_500_weth_without_fee"
        );
        fixtureZTx.push(withdrawZTx);
        fixtureZTx.push(transferZTx);

        if (block.chainid == 1 || block.chainid == 11155111) {
            ZTransaction memory swapZTx = _loadZTx(
                "swap_1e16_weth_without_fee"
            );
            fixtureZTx.push(swapZTx);
        }
    }

    function test_MultiTx() public {
        pool.transact(fixtureZTx[0]);
        pool.transact(fixtureZTx[1]);
        if (block.chainid == 1 || block.chainid == 11155111) {
            pool.transact(fixtureZTx[2]);
        }

        uint256 totalValue = token1.balanceOf(address(pool)) +
            token1.balanceOf(withdrawAddr);
        assertEq(totalValue, INITIAL_DEPOSIT);
    }
}
