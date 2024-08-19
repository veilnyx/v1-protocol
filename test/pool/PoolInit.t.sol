// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {AssetType, Asset} from "src/libraries/Asset.sol";
import {MerkleTree} from "src/libraries/MerkleTree.sol";
import {RevokerData} from "src/libraries/ShieldedTransaction.sol";
import {PoolStorage} from "src/base/PoolStorage.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolInitTest is PoolTest {
    function setUp() public {
        _setUp();
    }

    function test_correctParameters() public view {
        address verifier_ = pool.verifier();
        address adaptorHandler_ = pool.adaptorHandler();
        assertEq(verifier_, address(verifier));
        assertEq(adaptorHandler_, address(adaptorHandler));
        assertEq(commitmentTreeDepth, pool.getCommitmentTreeDepth());
        assertEq(addressTreeDepth, pool.getAddressTreeDepth());
    }

    function test_addAssets() external {
        AssetType assetType = AssetType.ERC20;
        address assetAddress = makeAddr("newAsset");
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = assetAddress;

        pool.addAssets(assetType, assetAddresses);

        bool isAssetSupported = pool.isAssetSupported(assetAddress);
        Asset memory newAsset = pool.getAsset(assetAddress);

        assert(isAssetSupported);
        assertNotEq(newAsset.id, 0);
        assert(newAsset.assetType == assetType);
        assertEq(newAsset.assetAddress, assetAddress);
    }

    ///////////////////////////
    ////// Revoker Tests  /////
    ///////////////////////////
    function test_registerRevoker() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerArrays();

        vm.expectEmit(true, true, true, true);
        emit IPool.RevokerRegistered(
            1,
            revokerKeys,
            encryptionKeys,
            revokerMetaData
        ); // one revoker already registered in PoolTest::_initFixture()

        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);
    }

    function test_revertWhenNonOwnerAddsRevoker() external {
        address random = makeAddr("random");
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerArrays();

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                random
            )
        );
        vm.prank(random);
        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);
    }

    function test_getRevoker() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerArrays();

        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);

        RevokerData memory cKeys = pool.getRevokerData(1); // one revoker already registered in PoolTest::_initFixture()
        assertEq(cKeys.revokerPublicKey[0], revokerKeys[0]);
        assertEq(cKeys.revokerPublicKey[1], revokerKeys[1]);
        assertEq(cKeys.encryptionPublicKey[0], encryptionKeys[0]);
        assertEq(cKeys.encryptionPublicKey[1], encryptionKeys[1]);

        assertTrue(cKeys.isActive);
    }

    function test_setRevokerStatus() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getRevokerArrays();

        pool.registerRevoker(revokerKeys, encryptionKeys, revokerMetaData);
        vm.expectEmit(true, true, true, true);
        emit IPool.RevokerStatusUpdated(1, false);
        pool.setRevokerStatus(1, false);

        RevokerData memory revoker = pool.getRevokerData(1);
        assertEq(revoker.isActive, false);
    }

    function _getRevokerArrays()
        internal
        pure
        returns (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        )
    {
        uint256 revokerKeyX = uint256(keccak256(bytes("revokerKeyX")));
        uint256 revokerKeyY = uint256(keccak256(bytes("revokerKeyX")));

        uint256 encryptionKeyX = uint256(keccak256(bytes("encryptionKeyX")));
        uint256 encryptionKeyY = uint256(keccak256(bytes("encryptionKeyX")));

        revokerKeys = [revokerKeyX, revokerKeyY];
        encryptionKeys = [encryptionKeyX, encryptionKeyY];

        return (revokerKeys, encryptionKeys);
    }
}
