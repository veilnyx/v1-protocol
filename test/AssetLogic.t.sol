// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {AssetType, Asset} from "../../src/libraries/DataTypes.sol";
import {AssetLogic} from "../../src/libraries/AssetLogic.sol";

contract AssetLogicTest is Test {
    address public t1 = address(1);
    address public t2 = address(2);
    address public t3 = address(3);

    mapping(address => uint24) internal _assetIds;
    mapping(uint24 => Asset) internal _assets;
    uint16 internal _counter;

    function test_addAsset() public {
        uint16 count = AssetLogic.addAsset(
            _assetIds,
            _assets,
            _counter,
            AssetType.ERC20,
            t1
        );
        assertEq(count, _counter + 1);

        bool supported = AssetLogic.isAssetSupported(_assetIds, _assets, t1);
        assertTrue(supported);
    }

    function test_addAssets() public {
        AssetType[] memory assetTypes = new AssetType[](3);
        assetTypes[0] = AssetType.ERC20;
        assetTypes[1] = AssetType.ERC20;
        assetTypes[2] = AssetType.ERC20;

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = t1;
        assetAddresses[1] = t2;
        assetAddresses[2] = t3;

        uint16 count = AssetLogic.addAssets(
            _assetIds,
            _assets,
            _counter,
            assetTypes,
            assetAddresses
        );

        assertEq(count, _counter + assetTypes.length);

        for (uint256 i = 0; i < assetAddresses.length; i++) {
            bool supported = AssetLogic.isAssetSupported(
                _assetIds,
                _assets,
                assetAddresses[i]
            );
            assertTrue(supported);
        }
    }
}
