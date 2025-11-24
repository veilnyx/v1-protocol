// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {AssetType} from "src/libraries/Asset.sol";

struct CommonConfig {
    uint256[] revokerPublicKey;
    uint256[] encryptionPublicKey;
}

/// @notice This contract is used to read the configuration from a script/config.json file (chain and common params).
contract Config is Script {
    uint256 public immutable chainId = block.chainid;
    uint256[2] internal _revokerPublicKey;
    uint256[2] internal _encryptionPublicKey;
    uint8 public immutable addressTreeDepth;
    uint8 public immutable commitmentTreeDepth;
    uint8 public immutable commitmentTreeQueueSize;
    uint256 public immutable withdrawFeeBps;
    address public immutable entryPoint;
    address public immutable gateway;
    address public immutable paymaster;
    address public immutable wToken;
    address public immutable sanctionsList;
    address public immutable nebraVerifier;

    AssetType public immutable initAssetType;
    address[] internal _initAssetAddresses;
    uint8[] internal _initAssetsPrecision;
    uint24[] internal _initAssetIdsVeilnyx;

    constructor() {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config.json"
        );
        string memory configJson = vm.readFile(path);

        // common config
        // _revokerPublicKey = [
        //     vm.parseJsonUint(configJson, ".common.revokerPublicKey[0]"),
        //     vm.parseJsonUint(configJson, ".common.revokerPublicKey[1]")
        // ];

        // _encryptionPublicKey = [
        //     vm.parseJsonUint(configJson, ".common.encryptionPublicKey[0]"),
        //     vm.parseJsonUint(configJson, ".common.encryptionPublicKey[1]")
        // ];

        addressTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".common.addressTreeDepth")
        );

        commitmentTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".common.commitmentTreeDepth")
        );

        commitmentTreeQueueSize = uint8(
            vm.parseJsonUint(configJson, ".common.commitmentTreeQueueSize")
        );

        withdrawFeeBps = vm.parseJsonUint(configJson, ".common.withdrawFeeBps");

        // chain specific config
        string memory chainPrefix = string.concat(".", vm.toString(chainId));

        entryPoint = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".entryPoint")
        );

        gateway = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".gateway")
        );

        paymaster = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".paymaster")
        );

        nebraVerifier = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".nebraVerifier")
        );

        wToken = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".wToken")
        );

        sanctionsList = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".sanctionsList")
        );

        initAssetType = AssetType(
            vm.parseJsonUint(
                configJson,
                string.concat(chainPrefix, ".initAssetType")
            )
        );

        _initAssetAddresses = vm.parseJsonAddressArray(
            configJson,
            string.concat(chainPrefix, ".initAssetAddresses")
        );

        uint256[] memory initAssetsPrecisionUint256 = vm.parseJsonUintArray(
            configJson,
            string.concat(chainPrefix, ".initAssetsPrecision")
        );
        _initAssetsPrecision = new uint8[](initAssetsPrecisionUint256.length);

        for (uint i = 0; i < initAssetsPrecisionUint256.length; i++) {
            _initAssetsPrecision[i] = uint8(initAssetsPrecisionUint256[i]);
        }

        uint256[] memory initAssetIdsUint256 = vm.parseJsonUintArray(
            configJson,
            string.concat(chainPrefix, ".initAssetIdsVeilnyx")
        );
        _initAssetIdsVeilnyx = new uint24[](initAssetIdsUint256.length);

        for (uint i = 0; i < initAssetIdsUint256.length; i++) {
            _initAssetIdsVeilnyx[i] = uint24(initAssetIdsUint256[i]);
        }
    }

    function revokerPublicKey() external view returns (uint256[2] memory) {
        return _revokerPublicKey;
    }

    function encryptionPublicKey() external view returns (uint256[2] memory) {
        return _encryptionPublicKey;
    }

    function initAssetAddresses() external view returns (address[] memory) {
        return _initAssetAddresses;
    }

    function initAssetsPrecision() external view returns (uint8[] memory) {
        return _initAssetsPrecision;
    }
}
