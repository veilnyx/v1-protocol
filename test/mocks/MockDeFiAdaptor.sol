// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdaptorBase} from "src/base/AdaptorBase.sol";
import {MockDeFi} from "./MockDeFi.sol";
import {AssetAmount} from "src/interfaces/IAdaptor.sol";

import {console2} from "forge-std/console2.sol";

contract MockDeFiAdaptor is ERC20, AdaptorBase {
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
        AssetAmount[] calldata inAssets,
        bytes calldata /*payload*/
    ) external payable override returns (AssetAmount[] memory outAssets) {
        address inAssetAddress = getAsset(inAssets[0].assetId).assetAddress;

        outAssets = new AssetAmount[](1);

        if (inAssetAddress == tokenAddress) {
            IERC20(inAssetAddress).approve(mockDefi, inAssets[0].value);
            MockDeFi(mockDefi).depositToken(address(this), inAssets[0].value);
            outAssets[0] = AssetAmount(getAssetId(mockDefi), inAssets[0].value);
        } else if (inAssetAddress == mockDefi) {
            MockDeFi(mockDefi).withdrawToken(address(this), inAssets[0].value);
            outAssets[0] = AssetAmount(
                getAssetId(tokenAddress),
                inAssets[0].value
            );
        } else {
            revert("MockDeFiProxy: Invalid asset");
        }
    }
}
