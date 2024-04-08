// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {PoolFixture} from "./fixtures/PoolFixture.sol";
import {TransactionRequest} from "./helpers/TransactionRequest.sol";

contract PoolDepositTest is PoolFixture {
    function setUp() public {
        _initFixture();
        _mockDeposit();
    }

    function test_depositTx() public {
        _mintAsset(asset1, address(this), 10 ether);
        _approveAsset(asset1, address(pool), 2 ether);
        TransactionRequest memory req = _createDepositReq(
            _getAssetId(asset1),
            1 ether
        );
        ZTransaction memory ztx = zkfi.getZTx(req);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(ztx.nullifiers[i]);
        }
        pool.transact(ztx);
        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        }
    }

    function test_depositMultiTx() public {
        _mintAsset(asset1, address(this), 10 ether);
        _mintAsset(asset2, address(this), 10 ether);
        _approveAsset(asset1, address(pool), 2 ether);
        _approveAsset(asset2, address(pool), 2 ether);

        TransactionRequest memory req = _createDepositReq(
            _getAssetId(asset1),
            1 ether,
            _getAssetId(asset2),
            1 ether
        );
        ZTransaction memory ztx = zkfi.getZTx(req);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(ztx.nullifiers[i]);
        }

        pool.transact(ztx);

        for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        }
    }
}
