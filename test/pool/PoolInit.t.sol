// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PoolTest} from "test/fixtures/PoolTest.t.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {AssetType, Asset} from "src/libraries/Asset.sol";
import {MerkleTree} from "src/libraries/MerkleTree.sol";
import {ComplianceKeys} from "src/libraries/ZTransaction.sol";
import {PoolStorage} from "src/base/PoolStorage.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PoolInitTest is PoolTest {
    function setUp() public {
        _initFixture();
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
    /// Compliance Keys Tests//
    ///////////////////////////
    function test_registerComplianceKey() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getComplianceKeyArrays();

        vm.expectEmit(true, true, false, true);
        emit IPool.RegisterComplianceKeys(0, revokerKeys, encryptionKeys);

        pool.registerComplianceKeys(revokerKeys, encryptionKeys);
    }

    function test_revertWhenNonOwnerAddsCompliance() external {
        address random = makeAddr("random");
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getComplianceKeyArrays();

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                random
            )
        );
        vm.prank(random);
        pool.registerComplianceKeys(revokerKeys, encryptionKeys);
    }

    function test_getComplianceKeys() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getComplianceKeyArrays();

        pool.registerComplianceKeys(revokerKeys, encryptionKeys);

        ComplianceKeys memory cKeys = pool.getComplianceKeys(0);
        assertEq(cKeys.revokerPublicKey[0], revokerKeys[0]);
        assertEq(cKeys.revokerPublicKey[1], revokerKeys[1]);
        assertEq(cKeys.encryptionPublicKey[0], encryptionKeys[0]);
        assertEq(cKeys.encryptionPublicKey[1], encryptionKeys[1]);

        assertTrue(cKeys.isActive);
    }

    function test_setComplianceKeysStatus() external {
        (
            uint256[2] memory revokerKeys,
            uint256[2] memory encryptionKeys
        ) = _getComplianceKeyArrays();

        pool.registerComplianceKeys(revokerKeys, encryptionKeys);
        pool.setComplianceKeysStatus(0, false);

        ComplianceKeys memory complianceKey = pool.getComplianceKeys(0);
        assertEq(complianceKey.isActive, false);
    }

    function _getComplianceKeyArrays()
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
