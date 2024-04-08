// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolFixture} from "./fixtures/PoolFixture.sol";
import {TransactionRequest} from "./helpers/TransactionRequest.sol";

contract PoolTransferTest is PoolFixture {
    function setUp() public {
        _initFixture();
        _mockDeposit();
    }

    function test_transferTx() public {
        TransactionRequest memory req = _createTransferReq(
            _getAssetId(asset1),
            1 ether
        );
        ZTransaction memory ztx = zkfi.getZTx(req);
        pool.transact(ztx);
    }

    // function test_transferMultiTx() public {
    //     TransactionRequest memory req = _createTransferReq(
    //         _getAssetId(asset1),
    //         1 ether,
    //         _getAssetId(asset2),
    //         1 ether
    //     );
    //     ZTransaction memory ztx = zkfi.getZTx(req);
    //     pool.transact(ztx);
    // }
}
