// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {IEthena} from "./IEthena.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Supports staking. User's will have to acquire USDe from external pools. Ref: https://ethena-labs.gitbook.io/ethena-labs/solution-design/key-addresses#liquidity-pool-contracts
/// @notice Unstaking is not supported. User's will have to unstake from Ethena's UI after withdrawing their `sUSDe` from Labyrinth. This is due to the cool down period required by Ethena before unstaking, making it a non-atomic tx.
contract EthenaAdaptor is AdaptorBase {
    IEthena public immutable ethena;
    // Ethena's stable coin that will be staked
    address public immutable USDe;
    // represents the share of USDe tokens staked in Ethena (non-rebasing)
    address public immutable sUSDe;

    constructor(
        address ethena_,
        address USDe_,
        address pool_
    ) AdaptorBase(pool_) {
        ethena = IEthena(ethena_);
        USDe = USDe_;
        sUSDe = ethena_;
    }

    function handleAssets(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata payload
    )
        external
        payable
        virtual
        override
        returns (uint24[] memory outAssetIds, uint256[] memory outValues)
    {
        Asset memory inAsset = getAsset(inAssetIds[0]);
        if (inAsset.assetAddress != USDe) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 stakeValue = inValues[0];
        if (stakeValue == 0) {
            revert ZeroValue();
        }

        // Staking request
        IERC20(USDe).approve(address(ethena), stakeValue);
        uint256 sUSDeShares = ethena.deposit(stakeValue, address(this));

        Asset memory outAsset = getAsset(sUSDe);

        outValues = new uint256[](1);
        outAssetIds = new uint24[](1);

        outAssetIds[0] = outAsset.id;
        outValues[0] = sUSDeShares;
    }
}
