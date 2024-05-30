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
    Verifier public verifier;
    Convertor public convertor;
    Pool public pool;
    ERC1967Proxy public poolProxy;

    uint256 public treeDepth = 32;
    address public entryPoint;
    address[2] assetAddresses;
    address uniswapSwapRouter02 = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

    function _runBaseTest() internal {
        vm.startBroadcast(vm.envUint("ANVIL_PRIVATE_KEY"));
        Verifier22 v22 = new Verifier22();
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        vInfos[0] = VerifierInfo({
            id: 2 * 10 + 2,
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        verifier = new Verifier(
            vInfos,
            _config.revokerPublicKey(),
            _config.encryptionPublicKey()
        );
        convertor = new Convertor();
        entryPoint = address(0);

        pool = new Pool();

        // Assets

        address[] memory assetAddressesArray = _config.initAssetAddresses();
        AssetType assetType = AssetType.ERC20;

        bytes memory initData = abi.encodeWithSelector(
            pool.initialize.selector,
            treeDepth,
            address(verifier),
            address(convertor),
            address(entryPoint),
            assetType,
            assetAddressesArray
        );

        poolProxy = new ERC1967Proxy(address(pool), initData);
        pool = Pool(address(poolProxy));
        vm.stopBroadcast();
    }
}

// contract BaseAdapterTest is BaseTest, BaseScript {
//     Verifier public verifier;
//     Convertor public convertor;
//     Pool public pool;
//     ERC1967Proxy public poolProxy;
//     address uniswapSwapRouter02;

//     function _runBaseTest() internal {
//         ZkFiDeploy zkFiDeployer = new ZkFiDeploy();
//         (verifier, convertor, pool, uniswapSwapRouter02) = zkFiDeployer.run();
//     }
// }
