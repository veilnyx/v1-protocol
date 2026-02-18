// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IAdaptor} from "../interfaces/IAdaptor.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";
import {PubAsset} from "../libraries/ShieldedTransaction.sol";

contract AdaptorHandler is IAdaptorHandler {
    using SafeERC20 for IERC20;

    /// @custom:invariant ADP-2: Output assets should be whitelisted in the protocol
    /// @custom:invariant ADP-3: Output value of each asset should be equal or less than the balance of that asset in this contract
    function handleAdaptor(
        address target,
        PubAsset[] calldata pubAssets,
        bytes calldata targetPayload
    ) external payable returns (PubAsset[] memory) {
        uint24[] memory inAssetIds = new uint24[](pubAssets.length);
        uint256[] memory inValues = new uint256[](pubAssets.length);
        for (uint8 i = 0; i < pubAssets.length; ) {
            inAssetIds[i] = pubAssets[i].id;
            inValues[i] = pubAssets[i].value;

            unchecked {
                ++i;
            }
        }

        (bool success, bytes memory res) = target.delegatecall(
            abi.encodeCall(
                IAdaptor.handleAssets,
                (inAssetIds, inValues, targetPayload)
            )
        );

        require(success, string(res));

        (uint24[] memory outAssetIds, uint256[] memory outValues) = abi.decode(
            res,
            (uint24[], uint256[])
        );

        Asset memory asset;
        uint256 assetBalance;

        PubAsset[] memory outPubAssets = new PubAsset[](outAssetIds.length);

        for (uint8 i = 0; i < outAssetIds.length; ) {
            asset = IPool(msg.sender).getAsset(outAssetIds[i]);

            if (!asset.isActive) {
                revert IPool.InactiveAsset(asset.id);
            }

            assetBalance = IERC20(asset.assetAddress).balanceOf(address(this));

            // Not checking for equality because of it might fail if somehow this contract
            // is sent tokens from other sources apart from doing shielded transactions. In that case,
            // balance will be greater than outValues[i] and revert will be called.
            if (assetBalance < outValues[i]) {
                revert InvalidOutputValue();
            }

            IERC20(asset.assetAddress).forceApprove(msg.sender, outValues[i]);

            outPubAssets[i] = PubAsset(outAssetIds[i], uint224(outValues[i]));

            // uint248(
            //     bytes31(
            //         bytes.concat(bytes3(outAssetIds[i]), bytes28(outValues[i]))
            //     )
            // );

            unchecked {
                ++i;
            }
        }

        return outPubAssets;
    }

    // Allow Lido/RocketPool adaptor to receive unwrapped Ether for staking
    receive() external payable {}
}
