// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/Asset.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {IAave} from "./IAave.sol";
import {IStaticAToken} from "./IStaticAToken.sol";

error UnsupportedAsset(uint24 assetId);
error InsufficientBalanceToLend();
error ZeroValues();
error ZeroAddress();

/// @notice Supports lending of wETH tokens to Aave and claiming the staked wETH tokens back.
contract AaveV3Adaptor is AdaptorBase {
    IAave public immutable aave;
    address public immutable WETH_LABYRINTH;
    // Address of the WETH token supported by Aave. Labyrinth's WETH (WETH_LABYRINTH) contract is diff. than the one supported by Aave.
    address public constant WETH_AAVE =
        0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c;
    // represents rebaseable aToken
    address public constant AWETH = 0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830;
    // represents the static form of AWETH tokens
    address public constant WRAPPED_AWETH =
        0x162B500569F42D9eCe937e6a61EDfef660A12E98;

    constructor(
        address aave_,
        address pool_,
        address WETH_LABYRINTH_
    ) AdaptorBase(pool_) {
        aave = IAave(aave_);
        WETH_LABYRINTH = WETH_LABYRINTH_;
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

        if (lendValue == 0) {
            revert ZeroValues();
        }

        if (inAsset.assetAddress == WETH_LABYRINTH) {
            // unwrapping WETH_LABYRINTH and converting into wEthAave.
            /// @notice This is done because the wEth contract address supported by Labyrinth and Aave are different. We will be using `WETH_AAVE` in this Aave adaptor.
            IWToken(WETH_LABYRINTH).withdraw(lendValue);
            IWToken(WETH_AAVE).deposit{value: lendValue}();

            if (IWToken(WETH_AAVE).balanceOf(address(this)) != lendValue) {
                revert InsufficientBalanceToLend();
            }

            // Step 1: Deposit WETH in Aave
            IWToken(WETH_AAVE).approve(address(aave), lendValue);
            aave.supply({
                asset: WETH_AAVE,
                amount: lendValue,
                // will receive aWETH tokens
                onBehalfOf: address(this),
                referralCode: 0
            });

            // rebasable aTokens by Aave
            uint256 aWethReceived = IERC20(AWETH).balanceOf(address(this));

            // Step 2: Convert aToken(rebasable) to static tokens as supported by Labyrith
            IERC20(AWETH).approve(WRAPPED_AWETH, aWethReceived);
            uint256 wEthStaticTokenBal = IStaticAToken(WRAPPED_AWETH).deposit({
                assets: aWethReceived,
                receiver: address(this),
                referralCode: 0,
                depositToAave: false
            });

            // Step 3: Prepare the output asset arrays
            Asset memory outAsset = getAsset(WRAPPED_AWETH);

            outValues = new uint256[](1);
            outAssetIds = new uint24[](1);

            outAssetIds[0] = outAsset.id;
            outValues[0] = wEthStaticTokenBal;
        } else {
            // Redeeming/Withdrawing
            if (inAsset.assetAddress != WRAPPED_AWETH) {
                revert UnsupportedAsset(inAsset.id);
            }

            address withdrawalAddress = abi.decode(payload, (address));
            if (withdrawalAddress == address(0)) {
                withdrawalAddress = address(this);
            }

            uint256 wEthStaticTokenBal = IERC20(WRAPPED_AWETH).balanceOf(
                address(this)
            );

            // Step 1: converting wrapped WETH to aWETH
            (, uint256 amountToWithdraw) = IStaticAToken(WRAPPED_AWETH).redeem({
                shares: wEthStaticTokenBal,
                receiver: address(this),
                owner: address(this),
                withdrawFromAave: false
            });

            // Step 2: withdrawing from Aave
            // taking the WETH_AAVE in adaptor so that it can be converted into the WETH_LABYRINTH. This is because the WETH contract used by Aave and Labyrinth are diff.
            IERC20(AWETH).approve(address(aave), amountToWithdraw);
            uint256 wEthAaveReceived = aave.withdraw({
                asset: WETH_AAVE,
                amount: amountToWithdraw,
                to: address(this)
            });

            if (withdrawalAddress == address(this)) {
                // Step 3: Converting WETH returned by Aave into WETH supported by Labyrinth
                IWToken(WETH_AAVE).withdraw(wEthAaveReceived);
                IWToken(WETH_LABYRINTH).deposit{value: wEthAaveReceived}();

                outAssetIds = new uint24[](1);
                outValues = new uint256[](1);

                outAssetIds[0] = getAsset(WETH_LABYRINTH).id;
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
}
