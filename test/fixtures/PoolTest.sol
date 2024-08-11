// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Pool} from "src/core/Pool.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ZTransaction, RevokerData} from "src/libraries/ZTransaction.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddress.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {MockScreener} from "test/mocks/MockScreener.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {PoolBaseTest} from "./PoolBaseTest.sol";

contract PoolTest is PoolBaseTest {
    Asset public asset1;
    Asset public asset2;

    bytes revokerMetaData = abi.encode("Revoker 1", "Organization 1");

    modifier expectNullifiersMarked(ZTransaction memory ztx_) {
        uint32 currentLeafIndex = pool.getCommitmentTreeNextLeafIndex();
        uint32 nullifierMarkLeafIndex = currentLeafIndex + 1;

        for (uint256 i = 0; i < ztx_.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(
                ztx_.nullifiers[i],
                nullifierMarkLeafIndex
            );
        }

        _;

        for (uint256 i = 0; i < ztx_.nullifiers.length; i++) {
            assertTrue(pool.isMarkedNullifier(ztx_.nullifiers[i]));
        }
    }

    modifier expectCommitmentsInserted(ZTransaction memory ztx) {
        uint256 nextIndex = pool.getCommitmentTreeNextLeafIndex();
        uint256 rootBeforeDeposit = pool.getCommitmentTreeLastRoot();
        uint256 currentRootIndexBeforeDeposit = pool
            .getCommitmentTreeCurrentRootIndex();

        for (uint256 i = 0; i < ztx.commitments.length; ++i) {
            vm.expectEmit(false, true, true, true);
            emit IPool.Commitment(nextIndex + i, ztx.commitments[i]);
        }

        _;

        uint256 nextLeafIndexAfterDeposit = pool
            .getCommitmentTreeNextLeafIndex();
        uint256 rootAfterDeposit = pool.getCommitmentTreeLastRoot();
        uint256 currentRootIndexAfterDeposit = pool
            .getCommitmentTreeCurrentRootIndex();

        // assertEq(nextIndex + ztx.commitments.length, nextLeafIndexAfterDeposit);
        // assertNotEq(rootBeforeDeposit, rootAfterDeposit);
        // assertLt(currentRootIndexBeforeDeposit, currentRootIndexAfterDeposit);
    }

    modifier expectReceipt(ZTransaction memory ztx) {
        uint32 nextLeafIndex = pool.getCommitmentTreeNextLeafIndex();

        vm.expectEmit(true, true, true, false);
        emit IPool.Receipt(
            ztx.txType,
            ztx.revokerId,
            (nextLeafIndex + uint32(ztx.commitments.length)),
            address(0),
            uint24(0),
            uint96(0),
            address(0),
            ztx.keysMemo,
            ztx.assetsMemo,
            ztx.notesMemo,
            bytes("")
        );

        _;
    }

    function _setUp() internal virtual override {
        PoolBaseTest._setUp();

        // Add assets
        // asset1 = Asset({
        //     id: 65537,
        //     assetType: AssetType.ERC20,
        //     assetAddress: address(token1),
        //     isSupported: true
        // });
        // asset2 = Asset({
        //     id: 65538,
        //     assetType: AssetType.ERC20,
        //     assetAddress: address(token2),
        //     isSupported: true
        // });
        AssetType assetType = AssetType.ERC20;
        address[] memory assetAddresses = new address[](2);
        assetAddresses[0] = address(token1);
        assetAddresses[1] = address(token2);
        pool.addAssets(assetType, assetAddresses);
        asset1 = pool.getAsset(assetAddresses[0]);
        asset2 = pool.getAsset(assetAddresses[1]);

        // Register revoker
        pool.registerRevoker(
            fixture.revokerPublicKey,
            fixture.encryptionPublicKey,
            revokerMetaData
        );

        // Register a user - "sender"
        (, uint256 senderPk) = makeAddrAndKey("sender");
        bytes memory signature = _getRegisterAddressSignature(
            senderPk,
            bytes.concat(
                bytes32(fixture.sender.rootAddress),
                bytes32(fixture.sender.signPublicKey[0]),
                bytes32(fixture.sender.signPublicKey[1]),
                bytes32(fixture.sender.viewPublicKey[0]),
                bytes32(fixture.sender.viewPublicKey[1])
            )
        );
        ShieldedAddressRegistrationData
            memory addressRegData = _loadShieldedAddressRegistrationData(
                "register_sender"
            );
        addressRegData.signature = signature;
        pool.registerAddress(addressRegData);
    }

    function _runExpectedTx(
        ZTransaction memory ztx
    )
        internal
        expectNullifiersMarked(ztx)
        expectCommitmentsInserted(ztx)
        expectReceipt(ztx)
    {
        pool.transact(ztx);
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
        return pool.getAsset(asset.assetAddress).id;
    }

    function _makePreDeposit() internal {
        uint256 deposit1 = 10000 ether;
        uint256 deposit2 = 10000e6;
        _mintAsset(asset1, address(this), deposit1);
        _mintAsset(asset2, address(this), deposit2);
        _approveAsset(asset1, address(pool), deposit1);
        _approveAsset(asset2, address(pool), deposit2);
        ZTransaction memory ztx = _loadShieldedTransaction(
            "deposit_1000_weth_usdc_without_fee"
        );
        for (uint256 i = 0; i < ztx.commitments.length; i++) {
            console2.log(i, ztx.commitments[i]);
        }
        pool.transact(ztx);
    }
}
