// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {ShieldedTransaction, ShieldedTransactionType, RevokerData} from "../libraries/ShieldedTransactionLogic.sol";
import {ShieldedAddressRegistrationData} from "../libraries/ShieldedAddressLogic.sol";
import {TreeUpdateData} from "../libraries/QueuedMerkleTreeLogic.sol";
import {AssetType, Asset, AssetInitParams} from "../libraries/AssetLogic.sol";
import {PoolStorage} from "../base/PoolStorage.sol";

import {IVerifier} from "./IVerifier.sol";
import {IAdaptorHandler} from "./IAdaptorHandler.sol";
import {IScreener} from "./IScreener.sol";
import {IHasher} from "./IHasher.sol";
import {IWToken} from "./IWToken.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @param verifier The address of the verifier contract. Verifier contract verifies the stx's zk proof, address proof and merkle tree queue proof.
/// @param adaptorHandler The address of the adaptor handler contract, responsible for delegate calling adaptors of external DeFi protocols.
/// @param screener The address of the screener contract, responsible for screening sanctioned addresseses.
///        Must either be a contract or address(0) (screening disabled); an EOA is rejected.
/// @param hasher The address of the hasher contract. It provides a single interface to Poseidon hashing functions
/// @param pauser The address allowed to pause the pool alongside the owner. Pass address(0)
///        to leave pausing exclusive to the owner; can later be set via `setPauser`.
struct InitAddressParams {
    IVerifier verifier;
    IAdaptorHandler adaptorHandler;
    IScreener screener;
    IHasher hasher;
    address pauser;
}

/// @param withdrawFeeBps Withdrawal fee in basis points (1 bps = 0.01%).
/// @param tvlLimitUsd Maximum allowed TVL in USD (6-decimal). type(uint256).max = no cap (unlimited).
/// @param minDepositUsd Minimum single-deposit value in USD (6-decimal). 0 = no minimum.
/// @param maxDepositUsd Maximum single-deposit value in USD (6-decimal). type(uint256).max = no maximum.
/// @param priceFeedStalenessThreshold Maximum age in seconds for a Chainlink price answer before it is considered stale.
/// @param nativeWToken Wrapped native token (e.g. WETH) used to wrap incoming msg.value
///        into the corresponding ERC20 deposit during DEPOSIT transactions.
///        Pass address(0) to disable native ETH deposits at deploy time; can
///        later be enabled by the owner via `setNativeWToken`.
struct PoolConfigParams {
    uint256 withdrawFeeBps;
    uint256 tvlLimitUsd;
    uint256 minDepositUsd;
    uint256 maxDepositUsd;
    uint256 priceFeedStalenessThreshold;
    IWToken nativeWToken;
}

interface IPool {
    /////////////////////////////////////////
    //            EVENTS                   //
    ////////////////////////////////////////

    event RegisterAddress(
        address indexed publicAddress,
        uint256 indexed rootAddress,
        uint32 indexed leafIndex,
        bytes shieldedAddress
    );
    event RevokerRegistered(
        uint256 indexed id,
        uint256[2] revokerPublicKey,
        uint256[2] encryptionPublicKey,
        bytes metadata
    );
    event RevokerStatusUpdated(uint256 indexed id, bool status);
    event VersionUpdated(uint64 indexed version);

    event AssetAdded(address indexed assetAddress, uint24 indexed assetId);
    event AssetStatusUpdated(uint24 indexed assetId, bool isActive);

    event NullifierMarked(uint256 indexed nullifier, uint32 indexed leafIndex);
    // Commitments
    event Commitment(uint256 indexed leafIndex, uint256 indexed commitment);

    event Receipt(
        ShieldedTransactionType indexed txType,
        uint16 indexed revokerId,
        uint32 lastLeafIndex,
        address indexed target,
        uint24 feeAssetId,
        uint96 feeValue,
        address paymaster,
        bytes keysMemo,
        bytes assetsMemo, // sent memo in case of transfer or calc from pub assets
        bytes notesMemo,
        bytes refundMemo
    );

    event WithdrawFeeUpdated(uint256 feeBps);

    event AssetUsdPriceFeedSet(
        uint24 indexed assetId,
        AggregatorV3Interface indexed feed
    );
    event TvlLimitUpdated(uint256 limit);
    event MinDepositUpdated(uint256 limit);
    event MaxDepositUpdated(uint256 limit);
    event PriceFeedStalenessThresholdUpdated(uint256 threshold);
    event NativeWTokenUpdated(IWToken indexed nativeWToken);
    event PauserUpdated(address indexed oldPauser, address indexed newPauser);
    event PriceStalenessThresholdUpdated(uint256 threshold);

    /////////////////////////////////////////
    //            ERRORS                   //
    ////////////////////////////////////////

    error RootAddressAlreadyRegistered(uint256 addr);
    error PublicAddressAlreadyRegistered(address addr);
    error BadArguments();
    error InvalidAddressProof();
    error RootAddrMismatch(
        uint256 proofForRootAddr,
        uint256 rootAddrBeingRegisted
    );
    error InvalidSubtreeUpdateProof();
    error InvalidTransactionProof();
    error UnknownCommitmentTreeRoot();
    error UnknownAddressTreeRoot();
    error DoubleSpend(uint256 markedNullifier);
    error UnsupportedAdaptor();
    error DuplicateAsset(address assetAddress);
    error InactiveAsset(uint24 assetId);
    error InvalidRevoker(uint256 id);
    error InvalidCurvePoint(uint256 x, uint256 y);
    error DuplicateRevoker(uint256[2] publicKey);
    error NoFeeToClaim(address paymaster, uint24 assetId);
    error WithdrawalFeeTooHigh(uint256 feeBps, uint256 maxFeeBps);
    error PubAssetsCannotExceedCommitments();
    error PriceFeedValueStale(uint24 assetId, uint256 updatedAt);
    error PriceFeedValueInvalid(uint24 assetId, int256 price);
    error TvlLimitExceeded(uint256 projectedTvl, uint256 limit);
    error PriceFeedStalenessThresholdTooLow(uint256 given, uint256 minimum);
    error DepositRestrictedAsAssetFeedNotSet(uint24 assetId);
    error DepositBelowMinimum(uint256 depositUsd, uint256 minDepositUsd);
    error DepositAboveMaximum(uint256 depositUsd, uint256 maxDepositUsd);
    /// @dev setScreener() was called with a non-zero address that holds no code.
    ///      An EOA screener would make every isSanctioned() call revert. The zero
    ///      address is still accepted — it is the kill-switch that disables screening.
    error InvalidScreenerAddress(address screener);

    /// @dev msg.value was sent for a non-DEPOSIT transaction. Native ETH is only
    ///      accepted on DEPOSIT to be wrapped into the configured nativeWToken.
    error NativeEthProvidedForNonDepositTx();

    /// @dev Native ETH received in receive() but nativeWToken has not been configured (address(0)).
    error NativeWTokenNotConfigured();

    /// @dev Native ETH received in receive() from an unexpected address (not nativeWToken).
    error UnexpectedNativeEthSender(address sender);

    /// @dev Native ETH was sent but the deposit transaction has no pubAsset
    ///      entry for the configured nativeWToken to match against.
    error WTokenNotInPubAssets();

    /// @dev pubAssets contains more than one entry for the same assetId.
    ///      A well-formed shielded transaction must list each asset at most
    ///      once.
    error DuplicatePubAssetId(uint24 assetId);

    /// @dev msg.value exceeds the (pre-fee) nativeWToken pubAsset value of the
    ///      deposit. Refusing to wrap to avoid locking the surplus ETH in the
    ///      Pool. Send `msg.value <= wTokenValue` and approve the nativeWToken
    ///      remainder if msg.value < wTokenValue.
    error NativeEthExceedsDeposit(uint256 sent, uint256 expected);
    error NotPauser();

    /// @dev renounceOwnership() was called. Ownership cannot be renounced
    ///      because the Pool would become permanently unadministrable.
    error RenounceDisabled();

    /////////////////////////////////////////
    //         ADMIN WRITE METHODS         //
    ////////////////////////////////////////

    /// @notice Pauses the contract. While paused, no transactions can be executed.
    /// @notice Can only be called by the pauser or the owner.
    function pause() external;

    /// @notice Unpauses the contract.
    /// @notice Can only be called by the owner.
    function unpause() external;

    /// @notice Delegates only the pausing right to `newPauser`. `unpause()` can still only be called by the owner.
    /// @notice Can only be called by the owner.
    /// @notice Even with an external pauser, the owner can still call `pause()` and `unpause()`.
    /// @param newPauser The address of the new pauser. Pass address(0) to revoke the dedicated pauser and revert control back to the owner exclusively.
    function setPauser(address newPauser) external;

    /// @notice Adds support for new assets in the protocol.
    /// @notice Can only be called by the owner.
    /// @param assetType The type of the asset to be added.
    /// @param initParams Per-asset parameters (address, precision, optional USD price feed).
    function addAssets(
        AssetType assetType,
        AssetInitParams[] calldata initParams
    ) external;

    /// @notice Adds support for an external adaptor to a DeFi protocol.
    /// @notice Can only be called by the owner.
    /// @param adaptorAddress The address of the adaptor contract.
    /// @param enable Whether to enable or disable the adaptor.
    function addAdaptorSupport(
        IAdaptorHandler adaptorAddress,
        bool enable
    ) external;

    /// @notice Activates or deactivates an existing asset.
    /// @notice Can only be called by the owner.
    /// @param assetId The 3-byte id of the asset to update.
    /// @param isActive Whether the asset should be active or inactive.
    function updateAssetStatus(uint24 assetId, bool isActive) external;

    /// @notice Registers a new revoker. Revokers are responsible for deanonymizing transactions along with a network of Guardians.
    /// @notice Can only be called by the owner.
    /// @param revokerPublicKey The public key of the revoker. Public key represents a point of the elliptic curve, hence it is a pair of two 256-bit integers.
    /// @param encryptionPublicKey The guardian network's public key used for encrypting the transactions.
    /// @param revokerMetadata Metadata for the revoker (e.g. name, description).
    function registerRevoker(
        uint256[2] calldata revokerPublicKey,
        uint256[2] calldata encryptionPublicKey,
        bytes calldata revokerMetadata
    ) external;

    /// @notice A function to withdraw the collected withdrawal fee for an asset by the protocol.
    /// @notice Can only be called by the owner.
    /// @param assetId The id of the asset for which the paymaster wants to claim the fee.
    /// @param to The address to which the fee will be transferred.
    function withdrawProtocolFee(uint24 assetId, address to) external;

    /// @notice Updates the status of a revoker.
    /// @notice Can only be called by the owner.
    function setRevokerStatus(uint256 index, bool status) external;

    /// @notice Sets the address of the address screener/sactionion contract.
    /// @notice Can only be called by the owner.
    function setScreener(IScreener screener) external;

    event ScreenerUpdated(address indexed screener);

    /// @notice Sets the no. of bips (basis points: 1/10000) fee that is charged for withdrawing assets from the pool.
    /// @notice Can only be called by the owner.
    function setWithdrawFeeBips(uint256 feeBips) external;

    /// @notice Registers a Chainlink-compatible USD price feed for an ERC20 asset.
    ///         Required for getTvlUsd() to include the asset in TVL calculation.
    /// @param assetId The 3-byte asset id to register the feed for.
    /// @param feed    Chainlink AggregatorV3Interface feed returning the asset price in USD.
    function setAssetPriceFeed(
        uint24 assetId,
        AggregatorV3Interface feed
    ) external;

    /// @notice Sets the maximum allowed TVL in USD (6-decimal precision).
    ///         type(uint256).max = no TVL cap (unlimited). Any other value is the hard cap.
    function setTvlLimitUsd(uint256 limitUsd) external;

    /// @notice Sets both deposit limits atomically.
    /// @dev Reverts with BadArguments if min > 0, max != type(uint256).max, and min > max.
    function setDepositLimits(uint256 minUsd, uint256 maxUsd) external;

    /// @notice Sets the maximum age of a Chainlink price answer before it is considered stale.
    /// @param threshold Age in seconds. Must be >= MIN_PRICE_STALENESS_THRESHOLD.
    function setPriceFeedStalenessThreshold(uint256 threshold) external;

    /// @notice Sets the wrapped native token (e.g. WETH) used to convert any
    ///         incoming `msg.value` into the corresponding ERC20 deposit during
    ///         a DEPOSIT transaction.
    /// @notice Can only be called by the owner.
    /// @param nativeWToken The wrapped native token contract. Pass address(0) to
    ///        disable native ETH deposits via this Pool.
    function setNativeWToken(IWToken nativeWToken) external;

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    /// @notice Registers a new user using their address hash in the protocol.
    /// @notice Can only be called when the contract is not paused.
    /// @param addressRegData The user's shielded address data including shielded address and proof.
    function registerAddress(
        ShieldedAddressRegistrationData calldata addressRegData
    ) external;

    /// @notice Updates the commitment tree with a queue of leaves. It uses zk proof under the hood to prove the `newRoot` and `newLevelSubtrees` are valid.
    /// @param updatedCommitmentTreeInputs The inputs needed by the zk verifier to verify the authenticity of the queued merkle tree update.
    function updateCommitmentTree(
        TreeUpdateData memory updatedCommitmentTreeInputs
    ) external;

    /// @notice Validates and executes a stx.
    /// @notice Can only be called when the contract is not paused.
    /// @notice Payable: when the transaction is a DEPOSIT and `nativeWToken` is set,
    ///         the caller may attach native ETH equal to the (pre-fee) nativeWToken
    ///         pubAsset value. The Pool then wraps the ETH into nativeWToken on
    ///         behalf of the caller in lieu of pulling nativeWToken from the caller's
    ///         wallet via `transferFrom`. msg.value of 0 preserves the
    ///         pre-existing ERC20 transferFrom flow for any asset (including
    ///         nativeWToken).
    /// @param stx The stx to be executed.
    function transact(ShieldedTransaction calldata stx) external payable;

    /// @notice A function to call by a paymaster contract to claim the asset wise fees collected for the ERC-4337 transactions they catered to.
    /// @notice Can only be called when the contract is not paused.
    /// @param assetId The id of the asset for which the paymaster wants to claim the fee.
    /// @param to The address to which the fee will be transferred.
    function withdrawPaymasterFee(uint24 assetId, address to) external;

    /////////////////////////////////////////
    //         READ METHODS                //
    ////////////////////////////////////////

    /// @notice Returns the data of an asset.
    /// @param assetId The id of the asset.
    function getAsset(uint24 assetId) external view returns (Asset memory);

    /// @notice Returns the data of an asset.
    /// @param assetAddress The address of the asset.
    function getAsset(
        address assetAddress
    ) external view returns (Asset memory);

    /// @notice Returns the collected paymaster fee for an asset by the protocol.
    /// @param assetId the asset id to get the fee for.
    /// @param paymaster the paymaster address claiming the fee
    function getCollectedPaymasterFee(
        uint24 assetId,
        address paymaster
    ) external view returns (uint256);

    /// @notice Returns the collected withdraw fee for an asset by the protocol.
    /// @param assetId The id of the asset.
    function getCollectedWithdrawFee(
        uint24 assetId
    ) external view returns (uint256);

    /// @notice Returns the data of a revoker.
    /// @param revokerId The id of the revoker.
    function getRevokerData(
        uint256 revokerId
    ) external view returns (RevokerData memory);

    /// @notice Returns if an external adaptor is supported.
    /// @param adaptorAddress The address of the adaptor.
    function isAdaptorSupported(
        IAdaptorHandler adaptorAddress
    ) external view returns (bool);

    /**
     * 
     * 
    /// @notice Returns the no. of assets supported by asset type.
    /// @param assetType The type of the asset. Ref. enum Asset::AssetType
    function assetCount(AssetType assetType) external view returns (uint24);

    /// @notice Returns if an asset is registered and active.
    /// @param assetAddress The address of the asset to check.
    function isAssetActive(address assetAddress) external view returns (bool);

    /// @notice Returns if an array of nullifiers are marked.
    /// @param nullifiers The array of nullifiers to check.
    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory);

    /// @notice Returns the depth of the commitment merkle tree.
    function getCommitmentTreeDepth() external view returns (uint8);

    /// @notice Returns the depth of the address merkle tree.
    function getAddressTreeDepth() external view returns (uint8);


    /// @notice Returns the next leaf index of the commitment merkle tree.
    function getCommitmentTreeNextLeafIndex() external view returns (uint32);

    /// @notice Returns the next leaf index of the address merkle tree.
    function getAddressTreeNextLeafIndex() external view returns (uint32);

     /// @notice Returns the lastest root of the commitment merkle tree.
    function getCommitmentTreeLastRoot() external view returns (uint256);

     /// @notice Returns the index of the commitment tree's root history array. We store a history of 100 roots for proof verification purposes.
    function getCommitmentTreeCurrentRootIndex()
        external
        view
        returns (uint256);

        /// @notice Returns the level hash of an empty merkle tree.
    function zeroes(uint8 level) external view returns (uint256);

    /// @notice Returns the lastest root of the address merkle tree.
    function getAddressTreeLastRoot() external view returns (uint256);

    /// @notice Returns the index of the address tree's root history array.
    function getAddressTreeCurrentRootIndex() external view returns (uint256);

    /// @notice Returns whether a root value is a known commitment tree root.
    /// @param root The root value to check.
    function isKnownCommitmentTreeRoot(
        uint256 root
    ) external view returns (bool);

    /// @notice Returns whether a root value is a known address tree root.
    /// @param root The root value to check.
    function isKnownAddressTreeRoot(uint256 root) external view returns (bool);
     */

    /// @notice Validates that the deposit amount in `stx` falls within the configured USD limits.
    /// @dev Call this before submitting a DEPOSIT transaction to surface limit violations early,
    ///      without spending gas on a full transaction. Non-DEPOSIT transactions always pass.
    ///      Limits are expressed in 6-decimal USD (e.g. 5_000_000 = $5.00).
    ///      A limit value of 0 means the corresponding check is disabled.
    /// @param stx The shielded transaction to validate.
    /// @custom:error DepositBelowMinimum Thrown when `minDepositUsd > 0` and the deposit
    ///               value is strictly less than `minDepositUsd`.
    /// @custom:error DepositAboveMaximum Thrown when `maxDepositUsd > 0` and the deposit
    ///               value is strictly greater than `maxDepositUsd`.
    function checkDepositWithinLimits(
        ShieldedTransaction calldata stx
    ) external view returns (bool);

    /// @notice Checks whether a pending deposit would push TVL above tvlLimitUsd.
    /// @dev Returns false when tvlLimitUsd is 0 (disabled) or stx is not a DEPOSIT.
    ///      Assets with no feed registered are excluded from the deposit-side sum.
    /// @param stx The shielded transaction to evaluate.
    /// @return crossed True if the deposit would cause TVL to exceed the limit.
    function isTvlLimitCrossed(
        ShieldedTransaction calldata stx
    ) external view returns (bool crossed);
}
