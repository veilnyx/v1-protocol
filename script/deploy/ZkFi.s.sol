// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Pool} from "src/core/Pool.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {VerifierInfo} from "src/core/Verifier.sol";
import {Verifier} from "src/core/Verifier.sol";
import {Convertor} from "src/core/Convertor.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {BaseScript} from "../BaseScript.sol";
import {console} from "forge-std/Test.sol";

contract ZkFiDeploy is BaseScript {
    function run() external broadcast returns (Pool, address) {
        Verifier22 v22 = new Verifier22();
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        Verifier verifier = new Verifier(
            vInfos,
            _config.revokerPublicKey(),
            _config.encryptionPublicKey()
        );

        Convertor convertor = new Convertor();
        Pool pool = new Pool();

        uint256 treeDepth = _config.treeDepth();
        address entryPoint = _config.entryPoint();
        AssetType initAssetType = _config.initAssetType();
        address[] memory initAssetAddresses = _config.initAssetAddresses();
        address uniswapSwapRouter02 = _config.uniswapSwapRouter02();

        bytes memory initializeData = abi.encodeCall(
            Pool.initialize,
            (
                treeDepth,
                address(verifier),
                address(convertor),
                entryPoint,
                initAssetType,
                initAssetAddresses
            )
        );

        ERC1967Proxy poolProxy = new ERC1967Proxy(
            address(pool),
            initializeData
        );
        pool = Pool(address(poolProxy));
        return (pool, uniswapSwapRouter02);
    }
}
