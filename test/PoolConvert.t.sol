// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "../../src/interfaces/IPool.sol";
import {Pool} from "../../src/core/Pool.sol";
import {Verifier} from "../../src/core/Verifier.sol";
import {Verifier22} from "../../src/verifiers/Verifier22.sol";
import {AssetType, VerifierInfo} from "../../src/libraries/DataTypes.sol";
import {ZTransaction, ZTransactionType} from "../../src/libraries/ZTransaction.sol";

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ZkFi, ZAccount} from "./helpers/ZkFi.sol";
import {PoolFixture} from "./fixtures/PoolFixture.sol";
import {TransactionRequest} from "./helpers/TransactionRequest.sol";
import {MockERC20} from "./fixtures/MockERC20.sol";
import {MockDeFi} from "./fixtures/MockDeFi.sol";
import {MockDeFiProxy} from "./fixtures/MockDeFiProxy.sol";

contract PoolConvertTest is PoolFixture {
    MockDeFi public mockDefi;
    MockDeFiProxy public mockDefiProxy;

    function setUp() public {
        _initFixture();
        mockDefi = new MockDeFi(asset1.assetAddress);
        mockDefiProxy = new MockDeFiProxy(
            address(pool),
            asset1.assetAddress,
            address(mockDefi)
        );
        pool.setProxy(address(mockDefiProxy), true);
        AssetType[] memory assetTypes = new AssetType[](1);
        assetTypes[0] = AssetType.ERC20;
        address[] memory addresses = new address[](1);
        addresses[0] = address(mockDefi);
        pool.addAssets(assetTypes, addresses);
        _mockDeposit();
    }

    function test_supportProxy() public {
        bool isSupported = pool.isProxySupported(address(mockDefiProxy));
        assertTrue(isSupported);
    }

    function test_convertTx() public {
        TransactionRequest memory req = _createConvertReq(
            _getAssetId(asset1),
            1 ether
        );
        req.to = abi.encode(address(mockDefiProxy));
        ZTransaction memory ztx = zkfi.getZTx(req);

        // for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
        //     vm.expectEmit(true, true, true, true);
        //     emit IPool.NullifierMarked(ztx.nullifiers[i]);
        // }

        pool.transact(ztx);

        // for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
        //     assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
        // }
    }

    // function test_convertMultiTx() public {
    //     _mintAsset(asset1, address(this), 10 ether);
    //     _mintAsset(asset2, address(this), 10 ether);
    //     _approveAsset(asset1, address(pool), 2 ether);
    //     _approveAsset(asset2, address(pool), 2 ether);

    //     TransactionRequest memory req = _createDepositReq(
    //         _getAssetId(asset1),
    //         1 ether,
    //         _getAssetId(asset2),
    //         1 ether
    //     );
    //     ZTransaction memory ztx = zkfi.getZTx(req);
    //     for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
    //         vm.expectEmit(true, true, true, true);
    //         emit IPool.NullifierMarked(ztx.nullifiers[i]);
    //     }

    //     pool.transact(ztx);

    //     for (uint256 i = 0; i < ztx.nullifiers.length; i++) {
    //         assertTrue(pool.isMarkedNullifier(ztx.nullifiers[i]));
    //     }
    // }
}
