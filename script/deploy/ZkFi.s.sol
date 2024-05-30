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

contract ZkFiDeploy is BaseScript {
    uint256 public constant REVOKER_PUBLIC_KEY_X =
        8116072818876777666029027213729376705234613448128995613697283149497235402123;
    uint256 public constant REVOKER_PUBLIC_KEY_Y =
        4598772416842731049226007701899382609184728232075557894618791492264594188716;

    uint256 public constant ENCRYPTION_PUBLIC_KEY_X =
        15187339732644800751812193648350861431733040013104897934882869545575329240973;
    uint256 public constant ENCRYPTION_PUBLIC_KEY_Y =
        18224946718075372665314217959364704865149122115871220475141871484502637776562;

    function run() external broadcast {
        // address verifier = _getContract("Verifier");
        // address convertor = _getContract("Convertor");
        // address poolImpl = _getContract("PoolImpl");

        Verifier22 v22 = new Verifier22();
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        Verifier verifier = new Verifier(
            vInfos,
            [REVOKER_PUBLIC_KEY_X, REVOKER_PUBLIC_KEY_Y],
            [ENCRYPTION_PUBLIC_KEY_X, ENCRYPTION_PUBLIC_KEY_Y]
        );
        Convertor convertor = new Convertor();
        Pool pool = new Pool();

        uint256 treeDepth = _config.treeDepth();
        address entryPoint = _config.entryPoint();
        AssetType initAssetType = _config.initAssetType();
        address[] memory initAssetAddresses = _config.initAssetAddresses();

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

        new ERC1967Proxy(address(pool), initializeData);
    }
}
