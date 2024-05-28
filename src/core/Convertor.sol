// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IConvertor} from "../interfaces/IConvertor.sol";
import {IConvertProxy} from "../interfaces/IConvertProxy.sol";
import {IPool} from "../interfaces/IPool.sol";
import {Asset, AssetType} from "../libraries/Asset.sol";

contract Convertor is IConvertor {
    using SafeERC20 for IERC20;

    function convert(
        address target,
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata targetPayload
    ) external payable returns (uint24[] memory, uint256[] memory) {
        (bool success, bytes memory res) = target.delegatecall(
            abi.encodeCall(
                IConvertProxy.convert,
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
        for (uint8 i = 0; i < outAssetIds.length; ) {
            asset = IPool(msg.sender).getAsset(outAssetIds[i]);

            if (!asset.isSupported) {
                revert("Unsupported asset");
            }

            assetBalance = IERC20(asset.assetAddress).balanceOf(address(this));

            // Not checking for equality because of it might fail if somehow this contract
            // is sent tokens from other sources apart from doing shielded transactions. In that case,
            // balance will be greater than outValues[i] and revert will be called.
            if (assetBalance < outValues[i]) {
                revert InvalidOutputValue();
            }

            IERC20(asset.assetAddress).forceApprove(msg.sender, outValues[i]);

            unchecked {
                ++i;
            }
        }

        return (outAssetIds, outValues);
    }
}
