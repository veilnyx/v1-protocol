// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPaymaster} from "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ShieldedTransaction} from "../libraries/ShieldedTransaction.sol";
import {PreVerificationDetails} from "../interfaces/IMempool.sol";
import {IPool} from "../interfaces/IPool.sol";

contract Paymaster is IPaymaster, Ownable {
    uint256 public constant VALIDATION_SUCCESS = 0;
    uint24 public constant ETH_ASSET_ID = 65537;
    uint8 public constant ETH_DECIMALS = 18;
    IEntryPoint public immutable entryPoint;
    address public immutable sender;

    /**
     * @dev Mapping from assetId to fee value.
     */
    mapping(uint24 => uint256) private _assetFees;
    /// @dev Mapping from assetId to fee value for outsourced verification tx. The gas cost for such tx will be lower due to the ZK proof verification being outsourced.
    mapping(uint24 => uint256) private _assetFeesForPreVerifiedTx;

    mapping(uint24 => address) public assetIdToChainlinkFeed;

    error InvalidPaymaster(address paymaster);
    error InvalidEntryPoint();
    error InvalidSender(address sender);
    error InvalidCallData();
    error InsufficientFee(uint256 given, uint256 required);
    error UnsupportedFeeAsset(uint24 asset);
    error ChainlinkPriceFeedNotFound(uint24 assetId);
    error ChainlinkPriceInvalid(int256 price);
    error ChainlinkDecimalsInvalid(uint24 assetId);
    error MaxCostEthToAssetConversionFailed(uint24 assetId);

    /**
     * params entryPoint_: Address of the entry point contract.
     * params sender_: Address of the gateway contract.
     */
    constructor(address entryPoint_, address sender_) Ownable(msg.sender) {
        entryPoint = IEntryPoint(entryPoint_);
        sender = sender_;
    }

    /**
     * Sets fee value for an asset.
     * @param assetId  - Asset id to update fee for.
     * @param feeValue - Fee value to set.
     */
    function setAssetFee(uint24 assetId, uint256 feeValue) external onlyOwner {
        _assetFees[assetId] = feeValue;
    }

    /**
     * Sets fee value for an asset for outsourced verification tx.
     * @param assetId  - Asset id to update fee for.
     * @param feeValue - Fee value to set.
     */
    function setAssetFeeForPreVerifiedTx(
        uint24 assetId,
        uint256 feeValue
    ) external onlyOwner {
        _assetFeesForPreVerifiedTx[assetId] = feeValue;
    }

    /**
     * Sets Chainlink feed address for an asset.
     * @param assetId - Asset id to update fee for.
     * @param feed    - Chainlink feed address.
     */
    function setChainlinkFeed(uint24 assetId, address feed) external onlyOwner {
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

    /**
     * Return fee value for an asset.
     */
    function getAssetFee(uint24 assetId) external view returns (uint256) {
        return _assetFees[assetId];
    }

    /**
     * Return fee value for an asset for outsourced verification tx.
     */
    function getAssetFeeForPreVerifiedTx(
        uint24 assetId
    ) external view returns (uint256) {
        return _assetFeesForPreVerifiedTx[assetId];
    }

    /// @notice Returns the `maxCostEth` value in fee asset using Chainlink's price feeds.
    function convertFeeFromEthToFeeAsset(
        uint256 maxCostEth,
        uint24 assetId
    ) public view returns (uint256 feeInAsset) {
        if (assetIdToChainlinkFeed[assetId] == address(0)) {
            revert ChainlinkPriceFeedNotFound(assetId);
        }

        AggregatorV3Interface feed = AggregatorV3Interface(
            assetIdToChainlinkFeed[assetId]
        );
        (, int256 price, , , ) = feed.latestRoundData();
        if (price <= 0) {
            revert ChainlinkPriceInvalid(price);
        }

        // for conversion we assume price fetching of assetId in ETH only since maxCostEth is in ETH
        uint8 decimals = feed.decimals();
        if (decimals != ETH_DECIMALS) {
            revert ChainlinkDecimalsInvalid(assetId);
        }

        feeInAsset = maxCostEth / uint256(price);

        if (feeInAsset == 0) {
            revert MaxCostEthToAssetConversionFailed(assetId);
        }

        return feeInAsset;
    }

    function isAssetFeeSupported(uint24 assetId) external view returns (bool) {
        return _assetFees[assetId] > 0;
    }

    function isAssetFeeSupportedForPreVerifiedTx(
        uint24 assetId
    ) external view returns (bool) {
        return _assetFeesForPreVerifiedTx[assetId] > 0;
    }

    /// @dev The only requirements for validation are
    ///     - sender should be the Gateway contract
    ///     - specified paymaster is this contract only (guarantee to receive fee to this contract)
    ///     - specified fee is sufficient
    /// Since this paymaster is only used by and meant for Labyrinth pool and the pool's `validateUserOp` already checks
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
        (ShieldedTransaction memory stx, ) = abi.decode(
            userOp.callData[4:],
            (ShieldedTransaction, PreVerificationDetails)
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
        if (feeAssetId == ETH_ASSET_ID) {
            return maxCostEth;
        }

        feeInAsset = convertFeeFromEthToFeeAsset(maxCostEth, feeAssetId);
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

    receive() external payable {}
}
