// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Pool} from "../../src/core/Pool.sol";
import {Verifier} from "../../src/core/Verifier.sol";
import {Verifier22} from "../../src/verifiers/Verifier22.sol";
import {AssetType, VerifierInfo} from "../../src/libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType} from "../../src/libraries/ZTransaction.sol";

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TransactionRequest} from "./helpers/TransactionRequest.sol";
import {ZkFi, ZAccount} from "./helpers/ZkFi.sol";
import {PoolFixture} from "./fixtures/PoolFixture.sol";

contract PoolWithdrawTest is PoolFixture {
    Pool internal _pool;
    Verifier internal _verifier;

    function setUp() public {
        _initFixture();
        _mockDeposit();
    }

    function test_withdrawTx() public {
        _mintAsset(asset1, address(this), 10 ether);
        _approveAsset(asset1, address(pool), 2 ether);

        TransactionRequest memory req = _createWithdrawReq(
            _getAssetId(asset1),
            1 ether
        );
        ZTransaction memory ztx = zkfi.getZTx(req);
        pool.transact(ztx);
    }

    function test_withdrawMultiTx() public {
        _mintAsset(asset1, address(this), 10 ether);
        _mintAsset(asset2, address(this), 10 ether);
        _approveAsset(asset1, address(pool), 2 ether);
        _approveAsset(asset2, address(pool), 2 ether);

        TransactionRequest memory req = _createWithdrawReq(
            _getAssetId(asset1),
            1 ether,
            _getAssetId(asset2),
            1 ether
        );
        ZTransaction memory ztx = zkfi.getZTx(req);
        pool.transact(ztx);
    }
}
