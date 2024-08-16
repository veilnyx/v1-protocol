// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Pool} from "src/core/Pool.sol";
import {Verifier, TransactionVerifierInfo} from "src/core/Verifier.sol";
import {AdaptorHandler} from "src/core/AdaptorHandler.sol";
import {VerifierTransact21} from "src/verifiers/VerifierTransact21.sol";
import {VerifierTransact22} from "src/verifiers/VerifierTransact22.sol";
import {VerifierRegister} from "src/verifiers/VerifierRegister.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {ZTransaction, ZTransactionType, RevokerData} from "src/libraries/ZTransaction.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTree.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddress.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {MockScreener} from "test/mocks/MockScreener.sol";
import {MockVerifier} from "test/mocks/MockVerifier.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockVerifier} from "test/mocks/MockVerifier.sol";
import {PoolBaseTest} from "./PoolBaseTest.sol";
import {console2} from "forge-std/console2.sol";

contract PoolTest is PoolBaseTest {
    using MerkleTreeLogic for MerkleTree;

    MockVerifier internal _mockVerifier = new MockVerifier();

    Asset public asset1;
    Asset public asset2;

    MerkleTree internal _helperTree;

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
        // uint256 rootBeforeDeposit = pool.getCommitmentTreeLastRoot();
        // uint256 currentRootIndexBeforeDeposit = pool
        //     .getCommitmentTreeCurrentRootIndex();

        uint256 nextLeafIndex = pool.getCommitmentTreeNextLeafIndex();

        for (uint256 i = 0; i < ztx.commitments.length; ++i) {
            vm.expectEmit(true, true, true, true);
            emit IPool.Commitment(nextLeafIndex + i, ztx.commitments[i]);
        }

        _;

        // uint256 nextLeafIndexAfterDeposit = pool
        //     .getCommitmentTreeNextLeafIndex();
        // uint256 rootAfterDeposit = pool.getCommitmentTreeLastRoot();
        // uint256 currentRootIndexAfterDeposit = pool
        //     .getCommitmentTreeCurrentRootIndex();

        // assertEq(nextIndex + ztx.commitments.length, nextLeafIndexAfterDeposit);
        // assertNotEq(rootBeforeDeposit, rootAfterDeposit);
        // assertLt(currentRootIndexBeforeDeposit, currentRootIndexAfterDeposit);
    }

    modifier expectReceipt(ZTransaction memory ztx) {
        uint32 nextLeafIndex = pool.getCommitmentTreeNextLeafIndex();
        address target = address(bytes20(ztx.targetData));

        uint24 feeAssetId = 0;
        uint96 feeValue = 0;
        address paymaster = address(0);

        // non transfer tx & transfer tx with fee
        if (ztx.pubAssets.length != 0) {
            feeAssetId = uint24(bytes3(bytes31(ztx.pubAssets[0])));
            feeValue = uint96(ztx.feeData);
            paymaster = address(bytes20(bytes32(ztx.feeData)));
        }

        if (ztx.txType != ZTransactionType.TRANSFER) {
            ztx.assetsMemo = abi.encodePacked(ztx.pubAssets);
        }

        vm.expectEmit(true, true, true, true);
        emit IPool.Receipt(
            ztx.txType,
            ztx.revokerId,
            (nextLeafIndex + uint32(ztx.commitments.length) - 1),
            target,
            feeAssetId,
            feeValue,
            paymaster,
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
        // Deposit 10000 WETH and 10000 USDC
        uint256 deposit1 = 10000 ether;
        uint256 deposit2 = 10000e6;
        _mintAsset(asset1, address(this), deposit1);
        _mintAsset(asset2, address(this), deposit2);
        _approveAsset(asset1, address(pool), deposit1);
        _approveAsset(asset2, address(pool), deposit2);
        ZTransaction memory ztx = _loadShieldedTransaction("deposit_pre_tx");
        pool.transact(ztx);

        // Process the batch
        uint256[] memory leaves = pool.getQueuedLeaves();
        uint8 depth = pool.getCommitmentTreeDepth();
        _helperTree.init(depth, address(hasher));
        for (uint256 i = 0; i < leaves.length; ++i) {
            _helperTree.insert(leaves[i]);
        }

        TreeUpdateData memory treeUpdateData = TreeUpdateData({
            newRoot: _helperTree.getLatestRoot(),
            newSubtrees: _helperTree.getLastSubtrees(),
            proof: bytes("")
        });

        _mockVerifierResult(true);
        pool.updateCommitmentTree(treeUpdateData);
        _mockVerifierReset();
    }

    function _mockVerifierResult(bool result) internal {
        pool.mock_verifier(address(_mockVerifier));
        _mockVerifier.setResult(result);
    }

    function _mockVerifierReset() internal {
        pool.mock_verifier(address(verifier));
    }

    // function _makePreDeposits() internal {
    //     console2.log("Making pre-deposits");
    //     // Deposits 100,000 ethers of each asset for each asset id
    //     pool.mock_queueCommitments(fixture.preDepositedNotesCommitments);
    //     console2.log("ckpt11");

    //     // Process the batch
    //     (uint256[] memory leaves, , , ) = pool.getCommitmentTreeState();
    //     console2.log("ckpt22");
    //     uint8 depth = pool.getCommitmentTreeDepth();
    //     console2.log("ckpt33");
    //     _helperTree.init(depth, address(hasher));
    //     for (uint256 i = 0; i < leaves.length; ++i) {
    //         // console2.log("ckpt44", i);
    //         _helperTree.insert(leaves[i]);
    //     }

    //     // console2.log("ckpt55");
    //     // console2.log("latestRoot", _helperTree.getLatestRoot());
    //     // console2.log("lastSubtrees", _helperTree.getLastSubtrees()[0]);
    //     TreeUpdateData memory treeUpdateData;
    //     treeUpdateData.newRoot = _helperTree.getLatestRoot();
    //     treeUpdateData.newSubtrees = new uint256[](depth);
    //     for (uint8 i = 0; i < depth; ++i) {
    //         // console2.log("i", i);
    //         treeUpdateData.newSubtrees[i] = _helperTree.lastSubtrees[i];
    //     }

    //     _mockVerifierResult(true);
    //     address vAddr = pool.verifier();
    //     console2.log("verifier", vAddr);
    //     console2.log("mockVer", address(_mockVerifier));
    //     console2.log("ckpt1");
    //     pool.updateCommitmentTree(treeUpdateData);
    //     console2.log("ckpt2");
    //     // _mockVerifierReset();
    //     console2.log("ckpt3");
    // }
}
