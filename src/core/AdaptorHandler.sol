// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IAdaptor, AssetAmount} from "../interfaces/IAdaptor.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";
import {PubAsset} from "../libraries/ShieldedTransaction.sol";

contract AdaptorHandler is IAdaptorHandler, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error AdaptorCallFailed(bytes reason);

    IPool public veilnyxPool;

    constructor() Ownable(msg.sender) {}

    modifier onlyPool() {
        if (address(veilnyxPool) == address(0)) {
            revert PoolNotSet();
        }

        if (msg.sender != address(veilnyxPool)) {
            revert OnlyPoolCanCall();
        }
        _;
    }

    function setVeilnyxPool(IPool _veilnyxPool) external onlyOwner {
        if (address(_veilnyxPool) == address(0)) revert ZeroAddress();
        veilnyxPool = _veilnyxPool;
    }

    /// @custom:invariant ADP-2: Output assets should be whitelisted in the protocol
    /// @custom:invariant ADP-3: Output value of each asset should be equal or less than the balance of that asset in this contract
    function handleAdaptor(
        address target,
        PubAsset[] calldata pubAssets,
        bytes calldata targetPayload
    ) external payable nonReentrant onlyPool returns (PubAsset[] memory) {
        AssetAmount[] memory inAssets = new AssetAmount[](pubAssets.length);
        for (uint256 i = 0; i < pubAssets.length; ) {
            inAssets[i] = AssetAmount(pubAssets[i].id, pubAssets[i].value);

            unchecked {
                ++i;
            }
        }

        (bool success, bytes memory res) = target.delegatecall(
            abi.encodeCall(IAdaptor.handleAssets, (inAssets, targetPayload))
        );

        if (!success) revert AdaptorCallFailed(res);

        AssetAmount[] memory outAssets = abi.decode(res, (AssetAmount[]));

        Asset memory asset;
        uint256 assetBalance;

        PubAsset[] memory outPubAssets = new PubAsset[](outAssets.length);

        for (uint256 i = 0; i < outAssets.length; ) {
            asset = veilnyxPool.getAsset(outAssets[i].assetId);

            if (!asset.isActive) {
                revert IPool.InactiveAsset(asset.id);
            }

            assetBalance = IERC20(asset.assetAddress).balanceOf(address(this));

            // Not checking for equality because of it might fail if somehow this contract
            // is sent tokens from other sources apart from doing shielded transactions. In that case,
            // balance will be greater than outAssets[i].value and revert will be called.
            if (assetBalance < outAssets[i].value) {
                revert InvalidOutputValue(
                    outAssets[i].assetId,
                    outAssets[i].value,
                    assetBalance
                );
            }

            IERC20(asset.assetAddress).forceApprove(
                address(veilnyxPool),
                outAssets[i].value
            );

            outPubAssets[i] = PubAsset(
                outAssets[i].assetId,
                uint224(outAssets[i].value)
            );

            unchecked {
                ++i;
            }
        }

        return outPubAssets;
    }

    // Allow Lido/RocketPool adaptor to receive unwrapped Ether for staking
    receive() external payable {}
}
