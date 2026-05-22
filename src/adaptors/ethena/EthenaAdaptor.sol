// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/Asset.sol";
import {IEthena} from "./IEthena.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AssetAmount} from "../../interfaces/IAdaptor.sol";
import {IPool} from "../../interfaces/IPool.sol";

/// @notice Supports staking. User's will have to acquire USDe from external pools. Ref: https://ethena-labs.gitbook.io/ethena-labs/solution-design/key-addresses#liquidity-pool-contracts
/// @notice Unstaking is not supported. User's will have to unstake from Ethena's UI after withdrawing their `sUSDe` from Veilnyx. This is due to the cool down period required by Ethena before unstaking, making it a non-atomic tx.
contract EthenaAdaptor is AdaptorBase {
    using SafeERC20 for IERC20;

    IEthena public immutable ethena;
    // Ethena's stable coin that will be staked
    IERC20 public immutable USDe;
    // represents the share of USDe tokens staked in Ethena (non-rebasing)
    IERC20 public immutable sUSDe;

    constructor(IEthena ethena_, IERC20 USDe_, IPool pool_) AdaptorBase(pool_) {
        ethena = ethena_;
        USDe = USDe_;
        sUSDe = IERC20(address(ethena_));
    }

    function handleAssets(
        AssetAmount[] calldata inAssets,
        bytes calldata /* payload */
    )
        external
        payable
        virtual
        override
        returns (AssetAmount[] memory outAssets)
    {
        if (inAssets.length != 1) {
            revert InvalidInputAssetLength(uint8(inAssets.length), 1);
        }

        Asset memory inAsset = getAsset(inAssets[0].assetId);
        if (inAsset.assetAddress != address(USDe)) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 stakeValue = inAssets[0].value;
        if (stakeValue == 0) {
            revert ZeroValue();
        }

        // Staking request
        USDe.forceApprove(address(ethena), stakeValue);
        uint256 sUSDeShares = ethena.deposit(stakeValue, address(this));

        Asset memory outAsset = getAsset(address(sUSDe));

        outAssets = new AssetAmount[](1);
        outAssets[0] = AssetAmount(outAsset.id, sUSDeShares);
    }
}
