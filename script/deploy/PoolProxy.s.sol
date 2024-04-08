// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Pool} from "src/core/Pool.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {BaseScript} from "../BaseScript.sol";

contract PoolProxyDeploy is BaseScript {
    function run() external broadcast {
        address verifier = _getContract("Verifier");
        address convertor = _getContract("Convertor");
        address poolImpl = _getContract("PoolImpl");

        uint256 treeDepth = _config.treeDepth();
        address entryPoint = _config.entryPoint();
        AssetType initAssetType = _config.initalAssetType();
        address[] memory initAssetAddresses = _config.initalAssetAddresses();

        // Pool poolImpl = new Pool(poolImpl);
        bytes memory initializeData = abi.encodeCall(
            Pool.initialize,
            (
                treeDepth,
                verifier,
                convertor,
                entryPoint,
                initAssetType,
                initAssetAddresses
            )
        );
        new ERC1967Proxy(address(poolImpl), initializeData);

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
