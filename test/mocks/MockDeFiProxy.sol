// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdaptorBase} from "src/base/AdaptorBase.sol";
import {MockDeFi} from "./MockDeFi.sol";

import {console2} from "forge-std/console2.sol";

contract MockDeFiProxy is ERC20, AdaptorBase {
    address public immutable tokenAddress;
    address public immutable mockDefi;

    constructor(
        address assetManager_,
        address tokenAddress_,
        address mockDefi_
    ) ERC20("MockDeFi", "MDF") AdaptorBase(assetManager_) {
        tokenAddress = tokenAddress_;
        mockDefi = mockDefi_;
    }

    function handleAssets(
        uint24[] calldata inAssetIds,
        uint256[] calldata inValues,
        bytes calldata /*payload*/
    ) external payable override returns (uint24[] memory, uint256[] memory) {
        address inAssetAddress = getAsset(inAssetIds[0]).assetAddress;

        uint24[] memory outAssetIds = new uint24[](1);
        uint256[] memory outValues = new uint256[](1);

        if (inAssetAddress == tokenAddress) {
            IERC20(inAssetAddress).approve(mockDefi, inValues[0]);
            MockDeFi(mockDefi).depositToken(address(this), inValues[0]);
            outAssetIds[0] = getAssetId(mockDefi);
        } else if (inAssetAddress == mockDefi) {
            MockDeFi(mockDefi).withdrawToken(address(this), inValues[0]);
            outAssetIds[0] = getAssetId(tokenAddress);
        } else {
            revert("MockDeFiProxy: Invalid asset");
        }

        outValues[0] = inValues[0];

        return (outAssetIds, outValues);
    }
}
