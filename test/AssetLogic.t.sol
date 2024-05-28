// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetType, Asset, AssetLogic} from "src/libraries/Asset.sol";

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
    }

    function test_addAssets() public {
        AssetType assetType = AssetType.ERC20;

        address[] memory assetAddresses = new address[](3);
        assetAddresses[0] = t1;
        assetAddresses[1] = t2;
        assetAddresses[2] = t3;

        uint16 count = AssetLogic.addAssets(
            _assetIds,
            _assets,
            _counter,
            assetType,
            assetAddresses
        );

        assertEq(count, _counter + assetAddresses.length);
    }
}
