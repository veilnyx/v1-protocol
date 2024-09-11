// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AdaptorBase} from "../../base/AdaptorBase.sol";
import {Asset, AssetType} from "../../libraries/Asset.sol";
import {IWToken} from "../../interfaces/IWToken.sol";
import {ICurvePool} from "./ICurvePool.sol";
import {console2} from "forge-std/src/console2.sol";

error InsufficientBalance();
error UnsupportedPool(address pool);
error InvalidInput();
error AssetNotSupportedByPool(address asset, address pool);

struct CoinSet {
    // Storage of coins in a pool
    address[] _coins;
    // Position is the index of the coin in the `_coins` array plus 1.
    // Position 0 is used to mean a value is not in the set.
    mapping(address coin => uint256) _positions;
}

contract CurveNGAdaptor is AdaptorBase, Ownable {
    ICurvePool public curve;
    /// @todo Add mapping to support multiple pools.
    /// @todo Support all coins of all pools supported
    /// @todo Support LP token of all pools supported. LP token and Curve pool share the same contract.

    /// @notice Liquidity pool and LP token share the same contract
    mapping(address pool => CoinSet) internal _poolForCoins;

    uint8 constant ACTION_SUPPLY = 0;
    uint8 constant ACTION_WITHDRAW = 1;

    constructor(address pool_) AdaptorBase(pool_) Ownable(msg.sender) {}

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
        (address pool, uint8 action) = abi.decode(payload, (address, uint8));
        CoinSet storage poolCoinSet = _poolForCoins[pool];
        uint256 poolCoinQty = poolCoinSet._coins.length;
        curve = ICurvePool(pool);

        if (poolCoinQty == 0) {
            revert UnsupportedPool(pool);
        }

        if (poolCoinQty != inAssetIds.length) {
            revert InvalidInput();
        }

        outAssetIds = new uint24[](1);
        outValues = new uint256[](1);

        if (action == ACTION_SUPPLY) {
            (outAssetIds[0], outValues[0]) = _supply(
                inAssetIds,
                inValues,
                poolCoinSet
            );
        }
        /**
        else if (action == ACTION_WITHDRAW) {
            (outAssetIds[0], outValues[0]) = _withdraw(
                inAssetIds[0],
                uint256(inValues[0])
            );
        } */
        else {
            revert InvalidAction();
        }
    }

    function _supply(
        uint24[] memory inAssetIds,
        uint256[] memory inValues,
        CoinSet storage poolCoinSet
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        console2.log("Adp::Inside _supply()");
        for (uint256 i = 0; i < inAssetIds.length; i++) {
            Asset memory inAsset = getAsset(inAssetIds[i]);
            address inputAsset = inAsset.assetAddress;
            uint256 lendValue = inValues[i];

            if (lendValue == 0) {
                revert ZeroValue();
            }

            if (poolCoinSet._positions[inputAsset] == 0) {
                revert AssetNotSupportedByPool(inputAsset, address(curve));
            }

            uint256 tokenBal = IERC20(inputAsset).balanceOf(address(this));
            if (tokenBal < lendValue) {
                revert InsufficientBalance();
            }

            IERC20(inputAsset).approve(address(curve), lendValue);
        }

        uint256 expectedLPTokens = calcLPTokens(inValues, true);
        console2.log("Adp::Expected LP Tokens: ", expectedLPTokens);

        // 0.5% slippage
        uint256 minLPTokens = expectedLPTokens -
            ((expectedLPTokens * 5) / 1000);

        uint256 lpTokens = curve.add_liquidity(
            inValues,
            minLPTokens,
            address(this)
        );
        console2.log("Adp::LP Tokens received: ", lpTokens);

        // LP tokens and Curve Pool share the same contract
        outAssetId = getAsset(address(curve)).id;
        outAssetValue = lpTokens;
    }

    /**
    function _withdraw(
        uint24 inAssetId,
        uint256 inValue
    ) internal returns (uint24 outAssetId, uint256 outAssetValue) {
        // Redeeming/Withdrawing
        Asset memory inAsset = getAsset(inAssetId);

        // static aToken -> aToken -> underlying asset
        address staticAToken = inAsset.assetAddress;
        address aToken = IStaticAToken(staticAToken).aToken();
        address underlyingAsset = IAToken(aToken).UNDERLYING_ASSET_ADDRESS();

        if (aToken == address(0)) {
            revert UnsupportedAsset(inAsset.id);
        }

        uint256 staticATokenBal = IERC20(staticAToken).balanceOf(address(this));
        if (staticATokenBal < inValue) {
            revert InsufficientBalance();
        }

        (, uint256 amountToWithdraw) = IStaticAToken(staticAToken).redeem({
            shares: staticATokenBal,
            receiver: address(this),
            owner: address(this),
            withdrawFromAave: false
        });

        IERC20(aToken).approve(address(aave), amountToWithdraw);
        uint256 underlyingAssetReceived = aave.withdraw({
            asset: underlyingAsset,
            amount: amountToWithdraw,
            to: address(this)
        });

        outAssetId = getAsset(underlyingAsset).id;
        outAssetValue = underlyingAssetReceived;
    }
     */

    function calcLPTokens(
        uint256[] memory amounts,
        bool isDeposit
    ) public view returns (uint256 lpTokenAmount) {
        return curve.calc_token_amount(amounts, isDeposit);
    }

    function addPool(address pool, address[] memory coins) external onlyOwner {
        /// @todo add check if pool already exists
        CoinSet storage coinSet = _poolForCoins[pool];

        if (coinSet._coins.length > 0) {
            revert InvalidInput();
        }

        coinSet._coins = coins;
        for (uint256 i = 0; i < coins.length; i++) {
            coinSet._positions[coins[i]] = i + 1;
        }
    }
}
