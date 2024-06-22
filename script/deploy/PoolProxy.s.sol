// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Pool} from "src/core/Pool.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {BaseScript} from "../BaseScript.sol";

contract PoolProxyDeploy is BaseScript {
    function run() external broadcast {
        address verifier = _getContract("Verifier");
        address convertor = _getContract("Convertor");
        address poolImpl = _getContract("PoolImpl");

        uint256 addressTreeDepth = _config.addressTreeDepth();
        uint256 commitmentTreeDepth = _config.commitmentTreeDepth();
        AssetType initAssetType = _config.initAssetType();
        address[] memory initAssetAddresses = _config.initAssetAddresses();

        bytes memory initializeData = abi.encodeCall(
            Pool.initialize,
            (addressTreeDepth, commitmentTreeDepth, verifier, convertor)
        );

        address proxyAddress = address(
            new ERC1967Proxy(address(poolImpl), initializeData)
        );

        Pool pool = Pool(proxyAddress);

        pool.addAssets(initAssetType, initAssetAddresses);
    }
}
