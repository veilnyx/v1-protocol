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
        address adaptorHandler = _getContract("AdaptorHandler");
        address screener = _getContract("Screener");
        address hasher = _getContract("Hasher");
        address poolImpl = _getContract("PoolImpl");

        uint8 addressTreeDepth = _config.addressTreeDepth();
        uint8 commitmentTreeDepth = _config.commitmentTreeDepth();
        uint256 withdrawFeeBps = _config.withdrawFeeBps();
        AssetType initAssetType = _config.initAssetType();
        address[] memory initAssetAddresses = _config.initAssetAddresses();
        uint256[2] memory revokerPublicKey = _config.revokerPublicKey();
        uint256[2] memory encryptionPublicKey = _config.encryptionPublicKey();

        bytes memory initializeData = abi.encodeCall(
            Pool.initialize,
            (
                addressTreeDepth,
                commitmentTreeDepth,
                verifier,
                adaptorHandler,
                screener,
                hasher,
                withdrawFeeBps
            )
        );

        address proxyAddress = address(
            new ERC1967Proxy(address(poolImpl), initializeData)
        );

        Pool pool = Pool(proxyAddress);

        pool.addAssets(initAssetType, initAssetAddresses);

        bytes memory metadata = abi.encode("Test Revoker", "Test Description");
        pool.registerRevoker(revokerPublicKey, encryptionPublicKey, metadata);
    }
}
