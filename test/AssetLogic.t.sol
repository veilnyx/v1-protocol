// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AssetType, Asset, AssetLogic, AssetInitParams} from "src/libraries/AssetLogic.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract AssetLogicTest is Test {
    address public t1 = address(1);
    address public t2 = address(2);
    address public t3 = address(3);
    uint8 public precision = 18;

    function setUp() public {
        vm.mockCall(
            t1,
            abi.encodeWithSignature("decimals()"),
            abi.encode(precision)
        );
        vm.mockCall(
            t2,
            abi.encodeWithSignature("decimals()"),
            abi.encode(precision)
        );
        vm.mockCall(
            t3,
            abi.encodeWithSignature("decimals()"),
            abi.encode(precision)
        );
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
            IERC20(t1),
            18,
            AggregatorV3Interface(address(0))
        );
        assertEq(count, _counter + 1);
    }

    function test_addAssets() public {
        AssetType assetType = AssetType.ERC20;

        AssetInitParams[] memory params = new AssetInitParams[](3);
        params[0] = AssetInitParams({assetAddress: t1, precision: 18, usdPriceFeed: AggregatorV3Interface(address(0))});
        params[1] = AssetInitParams({assetAddress: t2, precision: 6,  usdPriceFeed: AggregatorV3Interface(address(0))});
        params[2] = AssetInitParams({assetAddress: t3, precision: 18, usdPriceFeed: AggregatorV3Interface(address(0))});

        uint16 count = AssetLogic.addAssets(
            _assetIds,
            _assets,
            _counter,
            assetType,
            params
        );

        assertEq(count, _counter + params.length);
    }

    function test_duplicateAssetCheck() public {
        uint16 count = AssetLogic.addAsset(
            _assetIds,
            _assets,
            _counter,
            AssetType.ERC20,
            IERC20(t1),
            18,
            AggregatorV3Interface(address(0))
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
            IERC20(t1),
            18,
            AggregatorV3Interface(address(0))
        );
    }
}
