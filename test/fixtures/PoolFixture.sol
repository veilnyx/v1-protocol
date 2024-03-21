// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BaseFixture} from "./BaseFixture.sol";
import {MockERC20} from "./MockERC20.sol";

import {Pool} from "../../src/core/Pool.sol";
import {Verifier22} from "../../src/verifiers/Verifier22.sol";
import {VerifierInfo} from "../../src/libraries/DataTypes.sol";
import {Verifier} from "../../src/core/Verifier.sol";
import {Convertor} from "../../src/core/Convertor.sol";
import {Asset, AssetType} from "../../src/libraries/DataTypes.sol";
import {ZTransaction} from "../../src/libraries/ZTransaction.sol";

contract PoolFixture is BaseFixture {
    Verifier public verifier;
    Convertor public convertor;
    Pool public pool;

    uint256 public treeDepth = 24;
    address public entryPoint;

    MockERC20 public token1;
    MockERC20 public token2;

    Asset public asset1;
    Asset public asset2;

    function _initFixture() internal virtual override {
        BaseFixture._initFixture();
        Verifier22 v22 = new Verifier22();
        uint256[] memory ids = new uint256[](1);
        VerifierInfo[] memory vInfos = new VerifierInfo[](1);
        ids[0] = 2 * 10 + 2;
        vInfos[0] = VerifierInfo({
            addr: address(v22),
            selector: v22.verifyProof.selector
        });
        verifier = new Verifier(ids, vInfos);
        convertor = new Convertor();
        entryPoint = address(0);

        pool = new Pool();

        // Assets
        token1 = new MockERC20(address(this));
        token2 = new MockERC20(address(this));
        asset1 = Asset({
            assetType: AssetType.ERC20,
            assetAddress: address(token1),
            isSupported: true
        });
        asset2 = Asset({
            assetType: AssetType.ERC20,
            assetAddress: address(token2),
            isSupported: true
        });

        AssetType[] memory assetTypes = new AssetType[](2);
        assetTypes[0] = AssetType.ERC20;
        assetTypes[1] = AssetType.ERC20;
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(token1);
        assetAddresses[1] = address(token2);

        pool.initialize(
            treeDepth,
            address(verifier),
            address(convertor),
            address(entryPoint),
            assetTypes,
            assetAddresses
        );
    }

    function _mintAsset(
        Asset storage asset,
        address to,
        uint256 amount
    ) internal {
        MockERC20(asset.assetAddress).mint(to, amount);
    }

    function _approveAsset(
        Asset storage asset,
        address spender,
        uint256 amount
    ) internal {
        MockERC20(asset.assetAddress).approve(spender, amount);
    }

    function _getAssetId(Asset storage asset) internal view returns (uint24) {
        return pool.getAssetId(asset.assetAddress);
    }

    // Deposits 10000 ether
    function _mockDeposit() internal {
        string memory path = string.concat(
            vm.projectRoot(),
            "/test/fixtures/mock-deposit.txt"
        );
        string memory file = vm.readFile(path);
        bytes memory data = vm.parseBytes(file);
        ZTransaction memory ztx = abi.decode(data, (ZTransaction));

        _mintAsset(asset1, address(this), 10000 ether);
        _mintAsset(asset2, address(this), 10000 ether);
        _approveAsset(asset1, address(pool), 10000 ether);
        _approveAsset(asset2, address(pool), 10000 ether);
        pool.transact(ztx);
    }
}
