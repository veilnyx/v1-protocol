// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetType, Asset, AssetLogic} from "src/libraries/Asset.sol";
import {IPool} from "src/interfaces/IPool.sol";

contract AssetLogicTest is Test {
    address public t1 = address(1);
    address public t2 = address(2);
    address public t3 = address(3);
    uint8 public precision = 18;

    function setUp() public {
        vm.mockCall(t1, abi.encodeWithSignature("decimals()"), abi.encode(precision));
        vm.mockCall(t2, abi.encodeWithSignature("decimals()"), abi.encode(precision));
        vm.mockCall(t3, abi.encodeWithSignature("decimals()"), abi.encode(precision));
    }

    mapping(address => uint24) internal _assetIds;
    mapping(uint24 => Asset) internal _assets;
    uint16 internal _counter;

    function test_addAsset() public {
        uint16 count = AssetLogic.addAsset(
            _assetIds,
            _assets,
            _counter,
            AssetType.ERC20,
            t1,
            precision
        );
        assertEq(count, _counter + 1);
    }

    function test_addAssets() public {
        AssetType assetType = AssetType.ERC20;

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = t1;
        assetAddresses[1] = t2;
        assetAddresses[2] = t3;

        uint8[] memory assetsPrecision = new uint8[](3);
        assetsPrecision[0] = precision;
        assetsPrecision[1] = precision;
        assetsPrecision[2] = precision;

        uint16 count = AssetLogic.addAssets(
            _assetIds,
            _assets,
            _counter,
            assetType,
            assetAddresses,
            assetsPrecision
        );

        assertEq(count, _counter + assetAddresses.length);
    }

    function test_duplicateAssetCheck() public {
        uint16 count = AssetLogic.addAsset(
            _assetIds,
            _assets,
            _counter,
            AssetType.ERC20,
            t1,
            precision
        );
        uint24 newAssetId = _assetIds[t1];
        AssetLogic.updateAsset(_assets, newAssetId, false);

        vm.expectRevert(
            abi.encodeWithSelector(IPool.DuplicateAsset.selector, t1)
        );
        AssetLogic.addAsset(
            _assetIds,
            _assets,
            count,
            AssetType.ERC20,
            t1,
            precision
        );
    }
}
