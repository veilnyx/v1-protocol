// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Pool} from "src/core/Pool.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Verifier22} from "src/verifiers/Verifier22.sol";
import {VerifierInfo} from "src/core/Verifier.sol";
import {Verifier} from "src/core/Verifier.sol";
import {Convertor} from "src/core/Convertor.sol";
import {AssetType} from "src/libraries/Asset.sol";
import {BaseTest} from "test/fixtures/BaseTest.sol";
import {BaseScript} from "script/BaseScript.sol";
import {ZkFiDeploy} from "script/deploy/ZkFi.s.sol";

contract BaseAdapterTest is BaseTest, BaseScript {
    Pool public pool;
    address uniswapSwapRouter02;

    function _runBaseTest() internal {
        ZkFiDeploy zkFiDeployer = new ZkFiDeploy();
        (pool, uniswapSwapRouter02) = zkFiDeployer.run();
    }
}
