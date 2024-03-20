// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2} from "forge-std/console2.sol";
import {DeployScript} from "./DeployScript.sol";

import {Pool} from "src/core/Pool.sol";
import {Convertor} from "src/core/Convertor.sol";
import {AssetType} from "src/libraries/DataTypes.sol";

contract PoolDeploy is DeployScript {
    function _deploy() internal override {
        address verifier = _getContract("Verifier");
        address convertor = _getContract("Convertor");

        uint256 treeDepth = _config.treeDepth();
        address entryPoint = _config.entryPoint();
        AssetType[] memory initAssetTypes = _config.initalAssetTypes();
        address[] memory initAssetAddresses = _config.initalAssetAddresses();

        Pool pool = new Pool(entryPoint);
        pool.initialize(
            treeDepth,
            verifier,
            convertor,
            initAssetTypes,
            initAssetAddresses
        );
    }
}
