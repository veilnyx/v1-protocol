// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console2} from "forge-std/console2.sol";
import {DeployScript} from "./DeployScript.sol";
import {PoolProxy} from "./PoolProxy.sol";
import {Pool} from "src/core/Pool.sol";
import {AssetType} from "src/libraries/DataTypes.sol";

contract PoolProxyDeploy is DeployScript {
    function _deploy() internal override {
        address verifier = _getContract("Verifier");
        address convertor = _getContract("Convertor");
        uint256 treeDepth = _config.treeDepth();
        address entryPoint = _config.entryPoint();
        AssetType[] memory initAssetTypes = _config.initalAssetTypes();
        address[] memory initAssetAddresses = _config.initalAssetAddresses();

        Pool poolImpl = new Pool();
        bytes memory initializeData = abi.encodeCall(
            poolImpl.initialize,
            (
                treeDepth,
                verifier,
                convertor,
                entryPoint,
                initAssetTypes,
                initAssetAddresses
            )
        );
        PoolProxy poolProxy = new PoolProxy(address(poolImpl), initializeData);

        // Options memory opts;
        // opts.unsafeAllow = "external-library-linking";

        // address proxy = Upgrades.deployUUPSProxy(
        //     "Pool.sol",
        //     abi.encodeCall(
        //         Pool.initialize,
        //         (
        //             treeDepth,
        //             verifier,
        //             convertor,
        //             entryPoint,
        //             initAssetTypes,
        //             initAssetAddresses
        //         )
        //     ),
        //     opts
        // );
    }
}
