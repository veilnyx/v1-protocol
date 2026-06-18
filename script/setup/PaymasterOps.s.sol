// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "../BaseScript.sol";
import {console2} from "forge-std/console2.sol";

interface IPaymaster {
    function withdrawFromEntryPoint(
        address payable withdrawAddress,
        uint256 amount
    ) external;

    function getEntryPointDeposit() external view returns (uint256);

    function assetIdToChainlinkFeed(
        uint24 assetId
    ) external view returns (address);
}

contract PaymasterOps is BaseScript {
    address paymaster = 0x09Ddf21234094e89029451Fa677907Ad9fD9d06b;

    function _readChainlinkFeed() internal view {
        uint24 gasAssetId = 65538; // GAS_ASSET_ID (WETH)

        address feed = IPaymaster(paymaster).assetIdToChainlinkFeed(gasAssetId);
        console2.log("Chainlink feed for assetId 65538:", feed);

        if (feed == address(0)) {
            console2.log(
                "WARNING: No Chainlink feed configured for assetId 65538"
            );
        }
    }

    function _checkPaymasterDeposit() internal view {
        uint256 deposit = IPaymaster(paymaster).getEntryPointDeposit();
        console2.log("Current deposit: ", deposit);

        if (deposit < 1 ether) {
            console2.log(
                "WARNING: Paymaster deposit is below 1 ETH. Consider topping up."
            );
        }
    }

    function run() external broadcast {
        // _readChainlinkFeed();

        _checkPaymasterDeposit();
    }
}