// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {AssetType} from "src/libraries/Asset.sol";

struct CommonConfig {
    uint256[] revokerPublicKey;
    uint256[] encryptionPublicKey;
}

contract Config is Script {
    uint256 internal immutable _chainId = block.chainid;
    uint256 internal immutable _revokerPublicKeyX;
    uint256 internal immutable _revokerPublicKeyY;
    uint256 internal immutable _encryptionPublicKeyX;
    uint256 internal immutable _encryptionPublicKeyY;

    uint256 internal immutable _treeDepth = 32;
    address internal _entryPoint;
    address internal _wToken;

    AssetType internal immutable _initAssetType;
    address[] internal _initAssetAddresses;

    constructor() {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config.json"
        );
        string memory json = vm.readFile(path);
        _revokerPublicKeyX = vm.parseJsonUint(
            json,
            ".common.revokerPublicKey[0]"
        );
        _revokerPublicKeyY = vm.parseJsonUint(
            json,
            ".common.revokerPublicKey[1]"
        );

        _encryptionPublicKeyX = vm.parseJsonUint(
            json,
            ".common.encryptionPublicKey[0]"
        );

        _encryptionPublicKeyY = vm.parseJsonUint(
            json,
            ".common.encryptionPublicKey[1]"
        );

        string memory chainPrefix = string.concat(".", vm.toString(_chainId));

        _treeDepth = vm.parseJsonUint(
            json,
            string.concat(chainPrefix, ".treeDepth")
        );

        _entryPoint = vm.parseJsonAddress(
            json,
            string.concat(chainPrefix, ".entryPoint")
        );

        _wToken = vm.parseJsonAddress(
            json,
            string.concat(chainPrefix, ".wToken")
        );

        _initAssetType = AssetType(
            vm.parseJsonUint(json, string.concat(chainPrefix, ".initAssetType"))
        );

        _initAssetAddresses = vm.parseJsonAddressArray(
            json,
            string.concat(chainPrefix, ".initAssetAddresses")
        );
    }

    function revokerPublicKey() external view returns (uint256[2] memory) {
        return [_revokerPublicKeyX, _revokerPublicKeyY];
    }

    function encryptionPublicKey() external view returns (uint256[2] memory) {
        return [_encryptionPublicKeyX, _encryptionPublicKeyY];
    }

    function treeDepth() external pure returns (uint256) {
        return _treeDepth;
    }

    function entryPoint() external view returns (address) {
        return _entryPoint;
    }

    function wToken() external view returns (address) {
        return _wToken;
    }

    function initAssetType() external view returns (AssetType) {
        return _initAssetType;
    }

    function initAssetAddresses() external view returns (address[] memory) {
        address[] memory addresses = _initAssetAddresses;
        return addresses;
    }
}
