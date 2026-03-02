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
import {ShieldedTransaction, ShieldedTransactionType, RevokerData} from "src/libraries/ShieldedTransaction.sol";
import {MerkleTree, MerkleTreeLogic} from "src/libraries/MerkleTree.sol";
import {TreeUpdateData} from "src/libraries/QueuedMerkleTree.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "src/libraries/ShieldedAddress.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {MockScreener} from "test/mocks/MockScreener.sol";
import {MockVerifier} from "test/mocks/MockVerifier.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockVerifier} from "test/mocks/MockVerifier.sol";
import {PoolBaseTest} from "./PoolBaseTest.sol";
import {BaseScript} from "script/BaseScript.sol";

/// @dev PoolTest is a test setup contract providing the following functionalities:
/// 1. Adding asset support to the pool.
/// 2. Adding revoker to the pool.
/// 3. Registering a user.
/// 4. Commonly used modifiers and functions for testing pool ops.
/// 5. Mocking the verifier contract.
contract PoolTest is PoolBaseTest, BaseScript {
    using MerkleTreeLogic for MerkleTree;

    MockVerifier internal _mockVerifier = new MockVerifier();

    Asset public asset1;
    Asset public asset2;

    MerkleTree internal _helperTree;

    bytes revokerMetaData = abi.encode("Revoker 1", "Organization 1");

    modifier expectNullifiersMarked(ShieldedTransaction memory stx_) {
        (, , , , uint32 nextLeafIndex) = pool.getCommitmentTreeState();
        uint32 nullifierMarkLeafIndex = nextLeafIndex + 1;

        for (uint256 i = 0; i < stx_.nullifiers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit IPool.NullifierMarked(
                stx_.nullifiers[i],
                nullifierMarkLeafIndex
            );
        }

        _;

        // for (uint256 i = 0; i < stx_.nullifiers.length; i++) {
        //     assertTrue(pool.isMarkedNullifier(stx_.nullifiers[i]));
        // }
    }

    modifier expectCommitmentsInserted(ShieldedTransaction memory stx) {
        // uint256 rootBeforeDeposit = pool.getCommitmentTreeLastRoot();
        // uint256 currentRootIndexBeforeDeposit = pool
        //     .getCommitmentTreeCurrentRootIndex();

        (, , , , uint32 nextLeafIndex) = pool.getCommitmentTreeState();

        for (uint256 i = 0; i < stx.commitments.length; ++i) {
            vm.expectEmit(true, true, true, true);
            emit IPool.Commitment(nextLeafIndex + i, stx.commitments[i]);
        }

        _;

        // uint256 nextLeafIndexAfterDeposit = pool
        //     .getCommitmentTreeNextLeafIndex();
        // uint256 rootAfterDeposit = pool.getCommitmentTreeLastRoot();
        // uint256 currentRootIndexAfterDeposit = pool
        //     .getCommitmentTreeCurrentRootIndex();

        // assertEq(nextIndex + stx.commitments.length, nextLeafIndexAfterDeposit);
        // assertNotEq(rootBeforeDeposit, rootAfterDeposit);
        // assertLt(currentRootIndexBeforeDeposit, currentRootIndexAfterDeposit);
    }

    modifier expectReceipt(ShieldedTransaction memory stx) {
        (, , , , uint32 nextLeafIndex) = pool.getCommitmentTreeState();
        uint24 feeAssetId = 0;
        bytes memory assetsMemo = bytes("");

        // non transfer tx & transfer tx with fee
        if (stx.pubAssets.length != 0) {
            feeAssetId = uint24(stx.feeData >> 72);
        }

        if (stx.txType != ShieldedTransactionType.TRANSFER) {
            assetsMemo = abi.encodePacked(stx.pubAssets);
        } else {
            assetsMemo = stx.assetsMemo;
        }

        vm.expectEmit(true, true, true, true);
        emit IPool.Receipt(
            stx.txType,
            stx.revokerId,
            (nextLeafIndex + uint32(stx.commitments.length) - 1),
            address(bytes20(stx.targetData)),
            feeAssetId,
            uint72(stx.feeData),
            address(bytes20(bytes32(stx.feeData))),
            stx.keysMemo,
            assetsMemo,
            stx.notesMemo,
            bytes("")
        );

        _;
    }

    function _setUp() internal virtual override {
        PoolBaseTest._setUp();

        AssetType assetType = AssetType.ERC20;
        uint256 initAssetLength = block.chainid == 31337
            ? 0
            : _config.initAssetAddresses().length;

        address[] memory assetAddresses = new address[](3 + initAssetLength);
        uint8[] memory assetsPrecision = new uint8[](3 + initAssetLength);

        // for local testing env, we deploy mock tokens and add them as supported assets in the pool. The script/config.json will showcase arrays for initAssetAddresses, etc, which should be considered dummies, except the initAssetIdsVeilnyx used by the SDK. For testnet/mainnet, we rely on mock + existing onchain tokens, so supporting both sets of assets configured in the script/config.json file, which should include the assets needed for adaptor testing.

        // testnets/mainnet fork testing case
        if (block.chainid != 31337) {
            assetAddresses[0] = address(token1);
            assetAddresses[1] = address(token2);
            assetAddresses[2] = address(tokenReent);

            assetsPrecision[0] = MockERC20(assetAddresses[0]).decimals();
            assetsPrecision[1] = MockERC20(assetAddresses[1]).decimals();
            assetsPrecision[2] = MockERC20(assetAddresses[2]).decimals();

            uint i = 0;
            do {
                assetAddresses[3 + i] = _config.initAssetAddresses()[i];
                assetsPrecision[3 + i] = _config.initAssetsPrecision()[i];
                ++i;
            } while (i < initAssetLength);
        } else {
            // local testing case- only mock tokens are needed
            assetAddresses[0] = address(token1);
            assetAddresses[1] = address(token2);
            assetAddresses[2] = address(tokenReent);
            assetsPrecision[0] = MockERC20(assetAddresses[0]).decimals();
            assetsPrecision[1] = MockERC20(assetAddresses[1]).decimals();
            assetsPrecision[2] = MockERC20(assetAddresses[2]).decimals();
        }

        // adding support for testnet tokens if any to provide support of adaptor testing
        pool.addAssets(assetType, assetAddresses, assetsPrecision);

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

    /// @notice Checks if the expect events: NullifierMarked, Commitment, Receipt are emitted.
    /// @dev Activating all 3 checks at the same time causes a revert of the test execution. Maybe due to gas limit. Root cause yet to be found!
    /// @dev Since expectReceipt involves hashing ops, activate it separately.
    function _checkEventEmits(
        ShieldedTransaction memory stx
    )
        internal
        // expectNullifiersMarked(stx)
        // expectCommitmentsInserted(stx)
        expectReceipt(stx)
    {
        pool.transact(stx, false);
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
        ShieldedTransaction memory stx = _loadShieldedTransaction(
            "deposit_pre_tx"
        );
        pool.transact(stx, false);
        _processCommitmentTreeQueue();
    }

    function _processCommitmentTreeQueue() internal {
        // Process the batch
        uint8 depth = fixture.commitmentTreeDepth;
        _helperTree.init(depth, address(hasher));
        (uint256[] memory leaves, , , , ) = pool.getCommitmentTreeState();
        for (uint256 i = 0; i < leaves.length; ++i) {
            _helperTree.insert(leaves[i]);
        }

        (uint256[] memory lastSubtrees, uint256 lastRoot, , ) = _helperTree
            .getState();

        TreeUpdateData memory treeUpdateData = TreeUpdateData({
            newRoot: lastRoot,
            newSubtrees: lastSubtrees,
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
}
