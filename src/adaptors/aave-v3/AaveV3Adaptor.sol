// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "src/libraries/Asset.sol";
import {IAave} from "./IAave.sol";
import {IStaticAToken} from "./IStaticAToken.sol";
import {IWToken} from "src/interfaces/IWToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/Test.sol";

/// @notice Supports lending of wETH token for now
contract AaveV3Adaptor is AdaptorBase {
    error InactiveAsset(uint24 assetId);
    error UnsupportedAsset(uint24 assetId);
    error InsufficientBalanceToLend();
    error ZeroValues();
    error ZeroAddress();

    IAave public immutable iAave;
    address public immutable wEthLaby;
    address public constant WETH_AAVE =
        0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c; // Laby pool WETH contract is diff. than the one supported by Aave.
    address public constant A_WETH = 0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830; // represents rebaseable aToken
    address public constant WETH_STATIC_A_TOKEN =
        0x162B500569F42D9eCe937e6a61EDfef660A12E98; // represents the static aWETH tokens (wrapping aWETH -> stataWETH)

    constructor(
        address aave_,
        address pool_,
        address wEthLaby_
    ) AdaptorBase(pool_) {
        iAave = IAave(aave_);
        wEthLaby = wEthLaby_;
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
        uint256 lendValue = inValues[0];

        if (!inAsset.isActive) {
            revert InactiveAsset(inAssetIds[0]);
        }

        if (lendValue == 0) {
            revert ZeroValues();
        }

        if (inAsset.assetAddress == wEthLaby) {
            // unwrapping wEthLaby and converting into wEthAave.
            /// @notice This is done because the wEth contract address supported by Labyrinth and Aave are different. We will be using `WETH_AAVE` in this Aave adaptor.
            IWToken(wEthLaby).withdraw(lendValue);
            IWToken(WETH_AAVE).deposit{value: lendValue}();

            if (IWToken(WETH_AAVE).balanceOf(address(this)) != lendValue) {
                revert InsufficientBalanceToLend();
            }

            // Step 1: Deposit WETH in Aave
            IWToken(WETH_AAVE).approve(address(iAave), lendValue);
            iAave.supply({
                asset: WETH_AAVE,
                amount: lendValue,
                onBehalfOf: address(this), // will receive aWETH tokens
                referralCode: 0
            }); // supplying liquidity

            uint256 aWethReceived = IERC20(A_WETH).balanceOf(address(this)); // rebasable aTokens by Aave

            // Step 2: Convert aToken(rebasable) to staticAToken (static balance) as supported by Labyrith
            IERC20(A_WETH).approve(WETH_STATIC_A_TOKEN, aWethReceived);
            uint256 wEthStaticTokenBal = IStaticAToken(WETH_STATIC_A_TOKEN)
                .deposit({
                    assets: aWethReceived,
                    receiver: address(this),
                    referralCode: 0,
                    depositToAave: false
                }); // converting rebaseable aTokens to static staticATokens

            // Step 3: Prepare the output asset arrays
            // initializing the out token arrays
            Asset memory outAsset = getAsset(WETH_STATIC_A_TOKEN);
            if (!outAsset.isActive) {
                revert InactiveAsset(outAsset.id);
            }

            outValues = new uint256[](1);
            outAssetIds = new uint24[](1);

            outAssetIds[0] = outAsset.id;
            outValues[0] = wEthStaticTokenBal;
        } else {
            // Redeeming/Withdrawing
            if (inAsset.assetAddress != WETH_STATIC_A_TOKEN) {
                revert UnsupportedAsset(inAsset.id); // If not wEth, only wstEth is supported for claiming `unstEth` NFTs from Lido
            }

            address withdrawalAddress = abi.decode(payload, (address));
            if (withdrawalAddress == address(0)) {
                withdrawalAddress = address(this);
            }

            uint256 wEthStaticTokenBal = IERC20(WETH_STATIC_A_TOKEN).balanceOf(
                address(this)
            );

            // Step 1: converting static WETH to aWETH
            (, uint256 amountToWithdraw) = IStaticAToken(WETH_STATIC_A_TOKEN)
                .redeem({
                    shares: wEthStaticTokenBal,
                    receiver: address(this),
                    owner: address(this),
                    withdrawFromAave: false
                });

            // Step 2: withdrawing from Aave
            IERC20(A_WETH).approve(address(iAave), amountToWithdraw);
            uint256 wEthAaveReceived = iAave.withdraw({
                asset: WETH_AAVE,
                amount: amountToWithdraw,
                to: address(this) // taking the wETH_Aave in adaptor so that it can be converted into the wEth supported by Laby. This is because the WETH contract used by Aave and Labyrinth are diff.
            });

            if (withdrawalAddress == address(this)) {
                // Step 3: Converting WETH returned by Aave into WETH supported by Labyrinth
                IWToken(WETH_AAVE).withdraw(wEthAaveReceived);
                IWToken(wEthLaby).deposit{value: wEthAaveReceived}();

                outAssetIds = new uint24[](1);
                outValues = new uint256[](1);

                outAssetIds[0] = getAsset(wEthLaby).id;
                outValues[0] = wEthAaveReceived;
            } else {
                // adaptor transfers the receive WETH_Aave directly to the withdrawal address and returns nothing back into Labyrinth
                IWToken(WETH_AAVE).transfer(
                    withdrawalAddress,
                    wEthAaveReceived
                );
                outAssetIds = new uint24[](0);
                outValues = new uint256[](0);
            }
        }
    }

    /// @dev only for enabling `testWstEthUnstakingOnLido()` test. Pls comment this out for production use.
    // Allow Aave adaptor to receive unwrapped Ether for staking directly to Aave.
    // receive() external payable {}
}
