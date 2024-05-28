// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ZTransaction} from "src/libraries/ZTransaction.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {TransactionRequest} from "test/helpers/TransactionRequest.sol";
import {MockDeFi} from "test/mocks/MockDeFi.sol";
import {MockDeFiProxy} from "test/mocks/MockDeFiProxy.sol";

contract PoolConvertTest is PoolTest {
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
        pool.setConvertProxy(address(mockDefiProxy), true);
        AssetType assetType = AssetType.ERC20;
        address[] memory addresses = new address[](1);
        addresses[0] = address(mockDefi);
        pool.addAssets(assetType, addresses);
    }

    function test_supportProxy() public view {
        bool isSupported = pool.isConvertProxySupported(address(mockDefiProxy));
        assertTrue(isSupported);
    }
}
