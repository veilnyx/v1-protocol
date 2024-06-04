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
import {Gateway} from "src/core/Gateway.sol";
import {Paymaster} from "src/core/Paymaster.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {BaseScript} from "../BaseScript.sol";
import {console} from "forge-std/Test.sol";

contract ZkFiDeploy is BaseScript {
    function run() external broadcast returns (Pool, address, Paymaster) {
        // verifier
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

        // Convertor
        Convertor convertor = new Convertor();
        // Pool
        Pool pool = new Pool();

        address entryPoint = _config.entryPoint();

        bytes memory initializeData = abi.encodeCall(
            Pool.initialize,
            (
                _config.treeDepth(),
                address(verifier),
                address(convertor),
                _config.entryPoint(),
                _config.initAssetType(),
                _config.initAssetAddresses()
            )
        );
        // pool proxy
        ERC1967Proxy poolProxy = new ERC1967Proxy(
            address(pool),
            initializeData
        );
        pool = Pool(address(poolProxy));

        // Gateway
        address wToken = _config.wToken();
        Gateway gateway = new Gateway(entryPoint, wToken, address(pool));

        // Paymaster
        Paymaster paymaster = new Paymaster(entryPoint, address(gateway));
        console.log("Paymaster address:", address(paymaster));
        return (pool, _config.uniswapSwapRouter02(), paymaster);
    }
}
