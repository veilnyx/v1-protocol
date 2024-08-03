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
    uint256 public immutable chainId = block.chainid;
    uint256[2] internal _revokerPublicKey;
    uint256[2] internal _encryptionPublicKey;
    uint8 public immutable addressTreeDepth;
    uint8 public immutable commitmentTreeDepth;
    uint256 public immutable withdrawFeeBps;
    address public immutable entryPoint;
    address public immutable gateway;
    address public immutable paymaster;
    address public immutable wToken;
    address public immutable uniswapSwapRouter02;
    address public immutable lido;
    address public immutable withdrawalQueueERC721;
    address public immutable sanctionList;

    AssetType public immutable initAssetType;
    address[] internal _initAssetAddresses;

    constructor() {
        string memory path = string.concat(
            vm.projectRoot(),
            "/script/config.json"
        );
        string memory configJson = vm.readFile(path);

        // common config
        _revokerPublicKey = [
            vm.parseJsonUint(configJson, ".common.revokerPublicKey[0]"),
            vm.parseJsonUint(configJson, ".common.revokerPublicKey[1]")
        ];

        _encryptionPublicKey = [
            vm.parseJsonUint(configJson, ".common.encryptionPublicKey[0]"),
            vm.parseJsonUint(configJson, ".common.encryptionPublicKey[1]")
        ];

        addressTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".common.addressTreeDepth")
        );

        commitmentTreeDepth = uint8(
            vm.parseJsonUint(configJson, ".common.commitmentTreeDepth")
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

        wToken = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".wToken")
        );

        if(chainId == 11155111 || chainId == 1) {
            uniswapSwapRouter02 = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".uniswapSwapRouter02")
        );
        } else {
            uniswapSwapRouter02 = address(0);
        }

        if(chainId == 17000) {
            lido = vm.parseJsonAddress(configJson, string.concat(chainPrefix, ".lido"));
            withdrawalQueueERC721 = vm.parseJsonAddress(configJson, string.concat(chainPrefix, ".withdrawalQueueERC721"));
        } else {
            lido = address(0);
        }
        
        sanctionList = vm.parseJsonAddress(
            configJson,
            string.concat(chainPrefix, ".sanctionList")
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
}
