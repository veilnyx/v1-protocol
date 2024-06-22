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
    uint256 internal immutable _commitmentTreeDepth;
    uint256 internal immutable _addressTreeDepth;
    address internal _entryPoint;
    address internal _gateway;
    address internal _paymaster;
    address internal _wToken;
    address internal _uniswapSwapRouter02;
    address public chainalysisSanctionScreener;

    AssetType internal immutable _initAssetType;
    address[] internal _initAssetAddresses;

    constructor() {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config.json"
        );
        string memory configJson = vm.readFile(path);

        // common config
        _revokerPublicKeyX = vm.parseJsonUint(
            configJson,
            ".common.revokerPublicKey[0]"
        );
        _revokerPublicKeyY = vm.parseJsonUint(
            configJson,
            ".common.revokerPublicKey[1]"
        );

        _encryptionPublicKeyX = vm.parseJsonUint(
            configJson,
            ".common.encryptionPublicKey[0]"
        );

        _encryptionPublicKeyY = vm.parseJsonUint(
            configJson,
            ".common.encryptionPublicKey[1]"
        );

        _commitmentTreeDepth = vm.parseJsonUint(
            configJson,
            ".common.commitmentTreeDepth"
        );

        _addressTreeDepth = vm.parseJsonUint(
            configJson,
            ".common.addressTreeDepth"
        );

        // chain specific config
        string memory chainPrefix = string.concat(".", vm.toString(_chainId));

        _entryPoint = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".entryPoint")
        );

        _gateway = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".gateway")
        );

        _paymaster = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".paymaster")
        );

        _wToken = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".wToken")
        );

        _uniswapSwapRouter02 = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".uniswapSwapRouter02")
        );

        chainalysisSanctionScreener = vm.parseJsonAddress(configJson, string.concat(chainPrefix, ".chainalysisSanctionScreener"));

        _initAssetType = AssetType(
            vm.parseJsonUint(configJson, string.concat(chainPrefix, ".initAssetType"))
        );

        _initAssetAddresses = vm.parseJsonAddressArray(
            configJson,
            string.concat(chainPrefix, ".initAssetAddresses")
        );
    }

    function revokerPublicKey() external view returns (uint256[2] memory) {
        return [_revokerPublicKeyX, _revokerPublicKeyY];
    }

    function encryptionPublicKey() external view returns (uint256[2] memory) {
        return [_encryptionPublicKeyX, _encryptionPublicKeyY];
    }

    function commitmentTreeDepth() external view returns (uint256) {
        return _commitmentTreeDepth;
    }

    function addressTreeDepth() external view returns (uint256) {
        return _addressTreeDepth;
    }

    function gateway() external view returns (address) {
        return _gateway;
    }

    function paymaster() external view returns (address) {
        return _paymaster;
    }

    function entryPoint() external view returns (address) {
        return _entryPoint;
    }

    function sanctionScreener() external view returns (address) {
        return chainalysisSanctionScreener;
    }

    function wToken() external view returns (address) {
        return _wToken;
    }

    function uniswapSwapRouter02() external view returns (address) {
        return _uniswapSwapRouter02;
    }

    function initAssetType() external view returns (AssetType) {
        return _initAssetType;
    }

    function initAssetAddresses() external view returns (address[] memory) {
        address[] memory addresses = _initAssetAddresses;
        return addresses;
    }
}
