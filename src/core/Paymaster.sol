// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPaymaster} from "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransactionLogic.sol";
import {Asset, AssetLogic} from "../libraries/AssetLogic.sol";
import {IPool} from "../interfaces/IPool.sol";

contract Paymaster is IPaymaster, Ownable {
    uint256 public constant VALIDATION_SUCCESS = 0;
    uint24 public constant GAS_ASSET_ID = 65537; // AssetId for the active chain's native gas token
    uint8 public constant ETH_DECIMALS = 18;
    IEntryPoint public immutable entryPoint;
    address public immutable sender;
    IPool public immutable pool;

    mapping(uint24 => AggregatorV3Interface) public assetIdToChainlinkFeed;

    error InvalidPaymaster(address paymaster);
    error InvalidEntryPoint();
    error InvalidSender(address sender);
    error ZeroAddress();
    error InvalidCallData();
    error InsufficientFee(uint256 given, uint256 required);
    error FeeAssetNotSupportedByVeilnyx(uint24 assetId);
    error AssetNotSupportedAsFeeAsset(uint24 assetId);
    error ChainlinkPriceFeedNotFound(uint24 assetId);
    error ChainlinkPriceInvalid(
        int256 price,
        uint8 feedDecimals,
        uint256 updatedAt
    );
    error MaxCostEthToAssetConversionFailed(uint24 assetId);

    /**
     * params entryPoint_: Address of the entry point contract.
     * params sender_: Address of the gateway contract.
     */
    constructor(
        address entryPoint_,
        address sender_,
        address pool_
    ) Ownable(msg.sender) {
        if (
            entryPoint_ == address(0) ||
            sender_ == address(0) ||
            pool_ == address(0)
        ) revert ZeroAddress();
        entryPoint = IEntryPoint(entryPoint_);
        sender = sender_;
        pool = IPool(pool_);
    }

    /**
     * Sets Chainlink feed address for an asset.
     * @param assetId - Asset id to update fee for.
     * @param feed    - Chainlink feed address.
     */
    function setChainlinkFeed(
        uint24 assetId,
        AggregatorV3Interface feed
    ) external onlyOwner {
        assetIdToChainlinkFeed[assetId] = feed;
    }

    /**
     * Withdraw deposited value from entrypoint contract.
     * @param withdrawAddress - Target to send to.
     * @param amount          - Amount to withdraw.
     */
    function withdrawFromEntryPoint(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint.withdrawTo(withdrawAddress, amount);
    }

    /**
     * Withdraw any asset/fee from the deposit.
     * @param token  - Token to withdraw.
     * @param to     - Target to send to.
     * @param value  - Amount to withdraw.
     */
    function withdrawAsset(
        address token,
        address payable to,
        uint256 value
    ) external onlyOwner {
        if (token == address(0)) {
            Address.sendValue(to, value);
        } else {
            SafeERC20.safeTransfer(IERC20(token), to, value);
        }
    }

    /**
     * Add a deposit for this paymaster, used for paying for transaction fees.
     */
    function depositToEntryPoint() public payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /// @inheritdoc IPaymaster
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        _requireFromEntryPoint();
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    /// @inheritdoc IPaymaster
    function postOp(
        PostOpMode /*mode*/,
        bytes calldata /*context*/,
        uint256 /*actualGasCost*/,
        uint256 /*actualUserOpFeePerGas*/
    ) external pure override {
        revert("not supported");
    }

    /**
     * Return current paymaster's deposit on the entryPoint.
     */
    function getEntryPointDeposit() public view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /// @notice Returns the `maxCostEth` (native gas token of the active chain) value in `feeAssetId` using Chainlink's price feeds.
    function convertFeeFromGasTokenToFeeAsset(
        uint256 maxCostEth,
        uint24 feeAssetId
    ) public view returns (uint256 feeInAsset) {
        Asset memory feeAsset = pool.getAsset(feeAssetId);
        Asset memory gasAsset = pool.getAsset(GAS_ASSET_ID);

        if (!feeAsset.isActive) {
            revert FeeAssetNotSupportedByVeilnyx(feeAssetId);
        }

        // if chainlink feed for assetId not found, return maxCostEth
        if (
            address(assetIdToChainlinkFeed[feeAssetId]) == address(0) &&
            feeAssetId != GAS_ASSET_ID
        ) {
            revert AssetNotSupportedAsFeeAsset(feeAssetId);
        }

        if (
            address(assetIdToChainlinkFeed[feeAssetId]) == address(0) &&
            feeAssetId == GAS_ASSET_ID
        ) {
            // fee asset is GAS_TOKEN itself, returning default value
            return maxCostEth;
        }

        AggregatorV3Interface feed = assetIdToChainlinkFeed[feeAssetId];
        // for conversion we assume price fetching of assetId in ETH only since maxCostEth is in ETH
        uint8 feedDecimals = feed.decimals();

        (, int256 priceETHInAsset, , uint256 updatedAt, ) = feed
            .latestRoundData();
        if (
            priceETHInAsset <= 0 ||
            updatedAt > block.timestamp ||
            block.timestamp - updatedAt > 1 hours
        ) {
            revert ChainlinkPriceInvalid(
                priceETHInAsset,
                feedDecimals,
                updatedAt
            );
        }

        // returns fees in feeAsset's precision
        uint256 feePrec = feeAsset.precision;
        uint256 baseExp = gasAsset.precision + feedDecimals;
        feeInAsset = feePrec >= baseExp
            ? (maxCostEth *
                uint256(priceETHInAsset) *
                10 ** (feePrec - baseExp))
            : ((maxCostEth * uint256(priceETHInAsset)) /
                10 ** (baseExp - feePrec));

        if (feeInAsset == 0) {
            revert MaxCostEthToAssetConversionFailed(feeAssetId);
        }

        return feeInAsset;
    }

    /// @dev The only requirements for validation are
    ///     - sender should be the Gateway contract
    ///     - specified paymaster is this contract only (guarantee to receive fee to this contract)
    ///     - specified fee is sufficient
    /// Since this paymaster is only used by and meant for Veilnyx pool and the pool's `validateUserOp` already checks
    /// for validity of tx (so that it does not revert when called), we don't need to check those here.
    /// This paymaster must always maintain sufficient deposit in the `EntryPoint` contract to pay for gas.
    /// Note that it always reverts for invalid operations rather than returning.
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 maxCostEth
    ) internal view returns (bytes memory, uint256) {
        // Only support gateway contract as sender
        if (userOp.sender != sender) {
            revert InvalidSender(userOp.sender);
        }

        (
            address paymaster,
            uint24 feeAssetId,
            uint256 givenFee
        ) = _parseFeeParams(userOp);

        // Fee recipient must be this contract
        if (paymaster != address(this)) {
            revert InvalidPaymaster(paymaster);
        }

        uint256 requiredFee = _getRequiredFee(feeAssetId, maxCostEth);

        if (givenFee < requiredFee) {
            revert InsufficientFee(givenFee, requiredFee);
        }

        return ("", VALIDATION_SUCCESS);
    }

    function _parseFeeParams(
        PackedUserOperation calldata userOp
    ) internal pure returns (address, uint24, uint256) {
        ShieldedTransaction memory stx = abi.decode(
            userOp.callData[4:],
            (ShieldedTransaction)
        );

        // FeeData is packed as follows (in order):
        // 20 bytes - paymaster address
        // 3 bytes - feeAssetId (24 bits)
        // 9 bytes - feeValue (72 bits)
        address paymaster = address(uint160(stx.feeData >> (24 + 72)));

        // Extract the feeAssetId (3 bytes)
        uint24 feeAssetId = uint24(stx.feeData >> 72);

        // Extract the feeValue (9 bytes)
        uint256 feeValue = uint256(uint72(stx.feeData));

        return (paymaster, feeAssetId, feeValue);
    }

    /// @notice Returns `maxCostEth` amt of ETH in asset.
    function _getRequiredFee(
        uint24 feeAssetId,
        uint256 maxCostEth
    ) internal view returns (uint256 feeInAsset) {
        feeInAsset = convertFeeFromGasTokenToFeeAsset(maxCostEth, feeAssetId);
        return feeInAsset;
    }

    /**
     * Validate the call is made from a valid entrypoint
     */
    function _requireFromEntryPoint() internal virtual {
        if (msg.sender != address(entryPoint)) {
            revert InvalidEntryPoint();
        }
    }

    // Intentionally empty: allows this contract to receive native ETH for gas sponsorship flows.
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
