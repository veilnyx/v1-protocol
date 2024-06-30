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
    uint8 internal immutable _addressTreeDepth;
    uint8 internal immutable _commitmentTreeDepth;
    uint256 internal immutable _withdrawFeeBps;
    address internal _entryPoint;
    address internal _gateway;
    address internal _paymaster;
    address internal _wToken;
    address internal _uniswapSwapRouter02;
    address public chainalysisSanctionList;

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

        _addressTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".common.addressTreeDepth")
        );

        _commitmentTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".common.commitmentTreeDepth")
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

        _withdrawFeeBps = vm.parseJsonUint(
            configJson,
            string.concat(chainPrefix, ".withdrawFeeBps")
        );

        _wToken = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".wToken")
        );

        _uniswapSwapRouter02 = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".uniswapSwapRouter02")
        );

        chainalysisSanctionList = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".chainalysisSanctionList")
        );

        _initAssetType = AssetType(
            vm.parseJsonUint(
                configJson,
                string.concat(chainPrefix, ".initAssetType")
            )
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

    function addressTreeDepth() external view returns (uint8) {
        return _addressTreeDepth;
    }

    function commitmentTreeDepth() external view returns (uint8) {
        return _commitmentTreeDepth;
    }

    function gateway() external view returns (address) {
        return _gateway;
    }

    function paymaster() external view returns (address) {
        return _paymaster;
    }

    function withdrawFeeBps() external view returns (uint256) {
        return _withdrawFeeBps;
    }

    function entryPoint() external view returns (address) {
        return _entryPoint;
    }

    function sanctionList() external view returns (address) {
        return chainalysisSanctionList;
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
