// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IAdaptorHandler} from "src/interfaces/IAdaptorHandler.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {Pool} from "src/core/Pool.sol";
import {ShieldedTransaction} from "src/libraries/ShieldedTransactionLogic.sol";
import {AssetType} from "src/libraries/AssetLogic.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {MockDeFi} from "test/mocks/MockDeFi.sol";
import {MockDeFiAdaptor} from "test/mocks/MockDeFiAdaptor.sol";

contract PoolAdaptorTest is PoolTest {
    MockDeFi public mockDefi;
    MockDeFiAdaptor public mockDefiAdaptor;

    function setUp() public {
        _setUp();
        mockDefi = new MockDeFi(asset1.assetAddress);
        mockDefiAdaptor = new MockDeFiAdaptor(
            address(pool),
            asset1.assetAddress,
            address(mockDefi)
        );
        pool.addAdaptorSupport(IAdaptorHandler(address(mockDefiAdaptor)), true);
        AssetType assetType = AssetType.ERC20;
        address[] memory addresses = new address[](1);
        addresses[0] = address(mockDefi);
        uint8[] memory precisions = new uint8[](1);
        precisions[0] = 18;
        pool.addAssets(assetType, addresses, precisions, _mockFeedsArray(addresses.length));
    }

    function test_supportAdaptor() public view {
        bool isSupported = pool.isAdaptorSupported(
            IAdaptorHandler(address(mockDefiAdaptor))
        );
        assertTrue(isSupported);
    }

    // function test_callAdaptor() public {
    //     ShieldedTransaction memory stx = _loadShieldedTransaction(
    //         "transfer_500_weth_without_fee"
    //     );
    // }
}
