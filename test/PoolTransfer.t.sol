// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";

contract PoolTransferTest is PoolTest {
    function setUp() public {
        _initFixture();
        _makeInitialDeposit();
    }

    function test_transfer500WethWithoutFee() public {
        ZTransaction memory ztx = _loadZTx("transfer_500_weth_without_fee");
        pool.transact(ztx);
    }

    function test_transfer500WethWithWethFee() public {
        ZTransaction memory ztx = _loadZTx("transfer_500_weth_with_weth_fee");
        pool.transact(ztx);
    }
}
