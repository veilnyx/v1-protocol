// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IVerifier} from "../../src/interfaces/IVerifier.sol";
import {IPool} from "../../src/interfaces/IPool.sol";
import {IAdaptorHandler} from "../../src/interfaces/IAdaptorHandler.sol";
import {IScreener} from "../../src/interfaces/IScreener.sol";
import {PoolStorage} from "../../src/base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../../src/libraries/Asset.sol";
import {ZTransaction, ZTransactionLogic, RevokerData, VerifierAndAdpAddress} from "./MockZTransaction.sol";
import {MerkleTree, MerkleTreeLogic} from "../../src/libraries/MerkleTree.sol";

contract MockPool is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    PoolStorage
{
    using MerkleTreeLogic for MerkleTree;
    using ZTransactionLogic for ZTransaction;

    function initialize(
        uint256 addressTreeDepth,
        uint256 commitmentTreeDepth,
        address verifier_,
        address adaptorHandler_
    ) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        verifier = verifier_;
        adaptorHandler = adaptorHandler_;

        _addressTree.init(addressTreeDepth);
        _commitmentTree.init(commitmentTreeDepth);
    }

    /////////////////////////////////////////
    //         ADMIN WRITE METHODS         //
    ////////////////////////////////////////

    function addAssets(
        AssetType assetType,
        address[] memory assetAddresses
    ) external onlyOwner {
        _assetCounts[assetType] = AssetLogic.addAssets({
            assetIds: _assetIds,
            assets: _assets,
            counter: _assetCounts[assetType],
            assetType: assetType,
            assetAddresses: assetAddresses
        });
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function transact(
        ZTransaction memory ztx
    ) external nonReentrant whenNotPaused {
        ztx.execute({paymasterFees: _paymasterFees});
    }

    function claimPaymasterFeeCollected(
        uint24 assetId
    ) external nonReentrant whenNotPaused {
        address paymaster = msg.sender;
        uint256 fee = _paymasterFees[paymaster][assetId];
        if (fee == 0) {
            revert IPool.NoFeeToClaim(paymaster, assetId);
        }

        _paymasterFees[paymaster][assetId] = 0;
        AssetLogic.transferAsset({
            assets: _assets,
            to: paymaster,
            assetId: assetId,
            value: fee
        });
    }

    function getPaymasterFee(uint24 assertId) external view returns (uint256) {
        return _paymasterFees[msg.sender][assertId];
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
