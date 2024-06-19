// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {AssetType, Asset} from "src/libraries/Asset.sol";
import {MerkleTree} from "src/libraries/MerkleTree.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolInitTest is PoolTest {
    function setUp() public {
        _initFixture();
    }

    function test_correctParameters() public view {
        address verifier_ = pool.verifier();
        address adaptorHandler_ = pool.adaptorHandler();
        (uint256 revokerKeyX, uint256 revokerKeyY) = pool.getRevokerPublicKey();
        (uint256 encryptionKeyX, uint256 encryptionKeyY) = pool
            .getEncryptionPublicKey();

        assertEq(verifier_, address(verifier));
        assertEq(adaptorHandler_, address(adaptorHandler));
        assertEq(treeDepth, pool.getCommitmentTreeDepth());
        assertEq(treeDepth / 2, pool.getAddressTreeDepth());
        assertEq(revokerKeyX, fixture.revokerPublicKey[0]);
        assertEq(revokerKeyY, fixture.revokerPublicKey[1]);
        assertEq(encryptionKeyX, fixture.encryptionPublicKey[0]);
        assertEq(encryptionKeyY, fixture.encryptionPublicKey[1]);
    }

    function test_adding_asset() external {
        AssetType assetType = AssetType.ERC20;
        address assetAddress = makeAddr("newAsset");
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = assetAddress;

        pool.addAssets(assetType, assetAddresses);

        bool isAssetSupported = pool.isAssetSupported(assetAddress);
        Asset memory newAsset = pool.getAsset(assetAddress);

        assert(isAssetSupported);
        assert(newAsset.id != 0);
        assert(newAsset.assetType == assetType);
        assertEq(newAsset.assetAddress, assetAddress);
    }
}