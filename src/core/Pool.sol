// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool, InitAddressParams, PoolConfigParams} from "../interfaces/IPool.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IScreener} from "../interfaces/IScreener.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, MAX_WITHDRAW_FEE_BPS, TVL_USD_DECIMALS} from "../base/Constants.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic} from "../libraries/Asset.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTree.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "../libraries/QueuedMerkleTree.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "../libraries/ShieldedAddress.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType, RevokerData} from "../libraries/ShieldedTransaction.sol";

contract Pool is
    IPool,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    EIP712Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    PoolStorage
{
    using MerkleTreeLogic for MerkleTree;
    using QueuedMerkleTreeLogic for QueuedMerkleTree;
    using ShieldedAddressLogic for ShieldedAddressRegistrationData;
    using ShieldedTransactionLogic for ShieldedTransaction;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the Pool contract with the given parameters.
    /// @dev Pool is an UUPSUpgradeable contract, so it needs to be initialized.
    /// @param addressTreeDepth The depth of the address tree.
    /// @param commitmentTreeDepth The depth of the commitment tree.
    /// @param commitmentTreeQueueSize The size of the queue for the commitment tree. This determines how many leaves can be queued at MAX before a tree update is required. Defined by the circuit `treeUpdate::nLeaves`
    function initialize(
        uint8 addressTreeDepth,
        uint8 commitmentTreeDepth,
        uint8 commitmentTreeQueueSize,
        InitAddressParams calldata initAddressParams,
        PoolConfigParams calldata configParams
    ) external initializer {
        if (configParams.withdrawFeeBps > MAX_WITHDRAW_FEE_BPS) {
            revert IPool.WithdrawalFeeTooHigh(
                configParams.withdrawFeeBps,
                MAX_WITHDRAW_FEE_BPS
            );
        }

        __Ownable_init_unchained(msg.sender);
        __UUPSUpgradeable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();
        EIP712Upgradeable.__EIP712_init_unchained(
            EIP712_DOMAIN_NAME,
            EIP712_DOMAIN_VERSION
        );

        verifier = initAddressParams.verifier;
        adaptorHandler = initAddressParams.adaptorHandler;
        hasher = initAddressParams.hasher;
        screener = initAddressParams.screener;

        withdrawFeeBps = configParams.withdrawFeeBps;
        tvlLimitUsd = configParams.tvlLimitUsd;
        minDepositUsd = configParams.minDepositUsd;
        maxDepositUsd = configParams.maxDepositUsd;
        tvlPriceStalenessTreshold = configParams.tvlPriceStalenessTreshold;

        _addressTree.init(addressTreeDepth, hasher);
        _commitmentTree.init(
            commitmentTreeDepth,
            commitmentTreeQueueSize,
            hasher,
            verifier
        );
    }

    /////////////////////////////////////////
    //         ADMIN WRITE METHODS         //
    ////////////////////////////////////////
    /// @custom:invariant ACCESS-1 Owner can upgrade, pause, add assets/adaptors, register revokers
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addAssets(
        AssetType assetType,
        address[] calldata assetAddresses,
        uint8[] calldata precisions,
        AggregatorV3Interface[] calldata usdPriceFeeds
    ) external onlyOwner {
        _assetCounts[assetType] = AssetLogic.addAssets({
            assetIds: _assetIds,
            assets: _assets,
            assetCount: _assetCounts[assetType],
            assetType: assetType,
            assetAddresses: assetAddresses,
            precisions: precisions,
            usdPriceFeeds: usdPriceFeeds
        });
    }

    function addAdaptorSupport(
        IAdaptorHandler adaptorAddress,
        bool enable
    ) external onlyOwner {
        _adaptors[adaptorAddress] = enable;
    }

    function updateAssetStatus(
        uint24 assetId,
        bool isActive
    ) external onlyOwner {
        AssetLogic.updateAsset(_assets, assetId, isActive);
        emit IPool.AssetStatusUpdated(assetId, isActive);
    }

    function registerRevoker(
        uint256[2] calldata revokerPublicKey,
        uint256[2] calldata encryptionPublicKey,
        bytes calldata revokerMetadata
    ) external onlyOwner {
        uint16 id = _revokerCount;
        uint256 revokerPublicKeyHash = uint256(
            keccak256((abi.encode(revokerPublicKey)))
        );

        if (_revokerPublicKeys[revokerPublicKeyHash]) {
            revert DuplicateRevoker(revokerPublicKey);
        }

        _revokerPublicKeys[revokerPublicKeyHash] = true;

        RevokerData memory revokerData = RevokerData({
            id: id,
            isActive: true,
            revokerPublicKey: revokerPublicKey,
            encryptionPublicKey: encryptionPublicKey
        });

        _revokers[id] = revokerData;
        emit RevokerRegistered(
            id,
            revokerPublicKey,
            encryptionPublicKey,
            revokerMetadata
        );

        _revokerCount += 1;
    }

    function withdrawProtocolFee(
        uint24 assetId,
        address to
    ) external nonReentrant onlyOwner {
        uint256 withdrawFeeCollected = _withdrawFees[assetId];
        if (withdrawFeeCollected == 0) {
            revert NoFeeToClaim(msg.sender, assetId);
        }

        _withdrawFees[assetId] = 0;
        AssetLogic.transferAsset({
            assets: _assets,
            to: to,
            assetId: assetId,
            value: withdrawFeeCollected
        });
    }

    function setRevokerStatus(uint256 id, bool isActive) external onlyOwner {
        _revokers[id].isActive = isActive;
        emit IPool.RevokerStatusUpdated(id, isActive);
    }

    function setScreener(IScreener screener_) external onlyOwner {
        screener = screener_;
        emit ScreenerUpdated(address(screener_));
    }

    /// @custom:invariant FEE-1: withdrawFeeBps cannot be set above MAX_WITHDRAW_FEE_BPS
    function setWithdrawFeeBips(uint256 feeBps) external onlyOwner {
        if (feeBps > MAX_WITHDRAW_FEE_BPS) {
            revert IPool.WithdrawalFeeTooHigh(feeBps, MAX_WITHDRAW_FEE_BPS);
        }
        withdrawFeeBps = feeBps;
        emit WithdrawFeeUpdated(feeBps);
    }

    /// @notice Sets the protocol version number.
    /// @dev This is used to track the pool contract version since EIP-712 domain
    ///      name and version MUST NOT be changed (see README for critical warnings).
    /// @param version_ The new version number to set.
    function setVersion(uint64 version_) external onlyOwner {
        version = version_;
        emit IPool.VersionUpdated(version_);
    }

    /// @notice Registers a Chainlink-compatible USD price feed for an ERC20 asset.
    ///         Required for getTvlUsd() to include the asset in TVL calculation.
    /// @param assetId The 3-byte asset id to register the feed for.
    /// @param feed    Chainlink AggregatorV3Interface feed returning the asset price in USD.
    function setAssetPriceFeed(
        uint24 assetId,
        AggregatorV3Interface feed
    ) external onlyOwner {
        _setAssetPriceFeed(assetId, feed);
    }

    /// @notice Sets the maximum allowed TVL in USD (6-decimal precision, USDC/USDT standard).
    ///         Set to 0 to disable the TVL cap entirely.
    /// @custom:invariant TVL-1: deposits that push TVL above tvlLimitUsd are reverted
    function setTvlLimitUsd(uint256 limitUsd) external onlyOwner {
        tvlLimitUsd = limitUsd;
        emit IPool.TvlLimitUpdated(limitUsd);
    }

    /// @notice Sets the minimum allowed single-deposit value in USD (6-decimal precision).
    ///         Set to 0 to disable the minimum deposit check.
    function setMinDepositUsd(uint256 limitUsd) external onlyOwner {
        minDepositUsd = limitUsd;
        emit IPool.MinDepositUpdated(limitUsd);
    }

    /// @notice Sets the maximum allowed single-deposit value in USD (6-decimal precision).
    ///         Set to 0 to disable the maximum deposit check.
    function setMaxDepositUsd(uint256 limitUsd) external onlyOwner {
        maxDepositUsd = limitUsd;
        emit IPool.MaxDepositUpdated(limitUsd);
    }

    /// @notice Sets the maximum age of a Chainlink price answer before it is considered stale.
    /// @param threshold Age in seconds. A lower value is stricter; set to type(uint256).max to effectively disable the staleness check.
    function setTvlPriceStalenessTreshold(uint256 threshold) external onlyOwner {
        tvlPriceStalenessTreshold = threshold;
        emit IPool.TvlPriceStalenessTresholdUpdated(threshold);
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        ShieldedAddressRegistrationData calldata addressRegData
    ) external whenNotPaused {
        bytes32 hashTypedData = _hashTypedDataV4(
            ShieldedAddressLogic.hashRegsiterAddressStruct(
                addressRegData.shieldedAddress
            )
        );

        addressRegData.register({
            addressTree: _addressTree,
            publicAddresses: _publicAddresses,
            rootAddresses: _rootAddresses,
            verifier: verifier,
            hashTypedData: hashTypedData
        });
    }

    function updateCommitmentTree(
        TreeUpdateData calldata treeUpdateData
    ) external whenNotPaused {
        _commitmentTree.update(treeUpdateData);
    }

    function transact(
        ShieldedTransaction calldata stx
    ) public nonReentrant whenNotPaused {
        checkDepositWithinLimits(stx);
        _checkTvlLimitNotCrossed(stx);
        stx.validate({
            addressTree: _addressTree,
            commitmentTree: _commitmentTree,
            verifier: verifier,
            markedNullifiers: _markedNullifiers,
            supportedAdaptors: _adaptors,
            revokerDataMap: _revokers
        });

        stx.execute({
            commitmentTree: _commitmentTree,
            assets: _assets,
            paymasterFees: _paymasterFees,
            withdrawFees: _withdrawFees,
            hasher: hasher,
            adaptorHandler: adaptorHandler,
            withdrawFeeBps: withdrawFeeBps
        });
    }

    /// @custom:invariant ACCESS-3: Only paymasters can withdraw their accumulated fees
    function withdrawPaymasterFee(
        uint24 assetId,
        address to
    ) external nonReentrant whenNotPaused {
        address paymaster = msg.sender;
        uint256 fee = _paymasterFees[paymaster][assetId];
        if (fee == 0) {
            revert NoFeeToClaim(paymaster, assetId);
        }

        _paymasterFees[paymaster][assetId] = 0;
        AssetLogic.transferAsset({
            assets: _assets,
            to: to,
            assetId: assetId,
            value: fee
        });
    }

    /////////////////////////////////////////
    //         READ METHODS                //
    ////////////////////////////////////////

    /// @notice Returns the current total value locked in USD (6-decimal precision, USDC/USDT standard)
    ///         across all active ERC20 assets, using registered Chainlink USD price feeds.
    /// @dev Assets with no registered feed or that are inactive contribute 0 to the TVL.
    ///      Reverts with TvlPriceStale if a feed's answer is older than TVL_PRICE_STALENESS_THRESHOLD.
    ///      Reverts with TvlPriceInvalid if a feed returns a non-positive price.
    /// @return tvl Cumulative TVL in 6-decimal USD (e.g. 1_000_000 = $1).
    function getTvlUsd() public view returns (uint256 tvl) {
        uint16 erc20Count = _assetCounts[AssetType.ERC20];
        for (uint16 i = 1; i <= erc20Count; ) {
            uint24 assetId = (uint24(uint8(AssetType.ERC20)) << 16) | uint24(i);
            Asset memory asset = _assets[assetId];

            if (!asset.isActive || address(asset.usdPriceFeed) == address(0)) {
                unchecked {
                    ++i;
                }
                continue;
            }

            uint256 rawBalance = IERC20(asset.assetAddress).balanceOf(
                address(this)
            );
            tvl += _getUsdValue(asset, rawBalance);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Validates that the deposit amount in `stx` falls within the configured USD limits.
    /// @dev Call this before submitting a DEPOSIT transaction to surface limit violations early,
    ///      without spending gas on a full transaction. Non-DEPOSIT transactions always pass.
    ///      Limits are expressed in 6-decimal USD (e.g. 5_000_000 = $5.00).
    ///      A limit value of 0 means the corresponding check is disabled.
    /// @param stx The shielded transaction to validate.
    /// @custom:error DepositRestrictedAsAssetFeedNotSet Thrown when any deposit asset has no registered USD price feed.
    /// @custom:error DepositBelowMinimum Thrown when `minDepositUsd > 0` and the deposit
    ///               value is strictly less than `minDepositUsd`.
    /// @custom:error DepositAboveMaximum Thrown when `maxDepositUsd > 0` and the deposit
    ///               value is strictly greater than `maxDepositUsd`.
    function checkDepositWithinLimits(
        ShieldedTransaction calldata stx
    ) public view {
        if (stx.txType != ShieldedTransactionType.DEPOSIT) return;
        uint256 depositUsd = _getDepositUsd(stx);
        if (minDepositUsd > 0 && depositUsd < minDepositUsd) {
            revert IPool.DepositBelowMinimum(depositUsd, minDepositUsd);
        }
        if (maxDepositUsd > 0 && depositUsd > maxDepositUsd) {
            revert IPool.DepositAboveMaximum(depositUsd, maxDepositUsd);
        }
    }

    /// @notice Checks whether the pending deposit in `stx` would push TVL above `tvlLimitUsd`.
    /// @dev Only meaningful for DEPOSIT transactions. Returns false when tvlLimitUsd is 0 (disabled)
    ///      or when the transaction type is not DEPOSIT.
    ///      Reads deposited amounts from stx.pubAssets[]: each element encodes
    ///      assetId in the top 3 bytes and the raw token amount in the lower 224 bits.
    /// @param stx The shielded transaction to evaluate.
    /// @return crossed True if the deposit would cause TVL to exceed the limit.
    function isTvlLimitCrossed(
        ShieldedTransaction calldata stx
    ) public view returns (bool crossed) {
        if (tvlLimitUsd == 0 || stx.txType != ShieldedTransactionType.DEPOSIT) {
            return false;
        }
        crossed = (getTvlUsd() + _getDepositUsd(stx)) > tvlLimitUsd;
    }

    function getRevokerData(
        uint256 id
    ) external view returns (RevokerData memory) {
        return _revokers[id];
    }

    function getAsset(uint24 assetId) external view returns (Asset memory) {
        return _assets[assetId];
    }

    function getAsset(
        address assetAddress
    ) external view returns (Asset memory) {
        uint24 id = _assetIds[assetAddress];
        return _assets[id];
    }

    function getCollectedWithdrawFee(
        uint24 assetId
    ) external view returns (uint256) {
        return _withdrawFees[assetId];
    }

    function getCollectedPaymasterFee(
        uint24 assetId,
        address paymaster
    ) external view returns (uint256) {
        return _paymasterFees[paymaster][assetId];
    }

    function isAdaptorSupported(
        IAdaptorHandler adaptorAddress
    ) external view returns (bool) {
        return _adaptors[adaptorAddress];
    }

    function getCommitmentTreeState()
        external
        view
        returns (
            uint256[] memory queuedLeaves,
            uint256[] memory lastSubtrees,
            uint256 lastRoot,
            uint8 currentRootIndex,
            uint32 nextLeafIndex
        )
    {
        (
            queuedLeaves,
            lastSubtrees,
            lastRoot,
            currentRootIndex,
            nextLeafIndex
        ) = _commitmentTree.getState();
    }

    function getAddressTreeState()
        external
        view
        returns (
            uint256[] memory lastSubtrees,
            uint256 lastRoot,
            uint8 currentRootIndex,
            uint32 nextLeafIndex
        )
    {
        (lastSubtrees, lastRoot, currentRootIndex, nextLeafIndex) = _addressTree
            .getState();
    }

    function areMarkedNullifiers(
        uint256[] calldata nullifiers
    ) external view returns (bool[] memory) {
        bool[] memory markedArr = new bool[](nullifiers.length);
        uint256 nullifiersLen = nullifiers.length;

        for (uint256 i = 0; i < nullifiersLen; ) {
            markedArr[i] = _markedNullifiers[nullifiers[i]] != 0;

            unchecked {
                ++i;
            }
        }

        return markedArr;
    }

    function isKnownCommitmentTreeRoot(
        uint256 root
    ) external view returns (bool) {
        return _commitmentTree.isKnownRoot(root);
    }

    function isKnownAddressTreeRoot(uint256 root) external view returns (bool) {
        return _addressTree.isKnownRoot(root);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _setAssetPriceFeed(
        uint24 assetId,
        AggregatorV3Interface feed
    ) private {
        _assets[assetId].usdPriceFeed = feed;
        emit IPool.AssetUsdPriceFeedSet(assetId, address(feed));
    }

    function _checkTvlLimitNotCrossed(
        ShieldedTransaction calldata stx
    ) private view {
        if (isTvlLimitCrossed(stx)) {
            uint256 projectedTvl = getTvlUsd() + _getDepositUsd(stx);
            revert IPool.TvlLimitExceeded(projectedTvl, tvlLimitUsd);
        }
    }

    /// @notice Returns the USD value of `amount` units of `asset` using its registered Chainlink feed.
    /// @dev Reverts with TvlPriceFeedNotSet if no feed is registered for the asset.
    ///      Reverts with TvlPriceStale / TvlPriceInvalid on bad feed data.
    /// @param asset  The Asset struct (must have usdPriceFeed set).
    /// @param amount Raw token amount (in the asset's native precision).
    /// @return usdValue Amount expressed in 6-decimal USD.
    function _getUsdValue(
        Asset memory asset,
        uint256 amount
    ) internal view returns (uint256 usdValue) {
        AggregatorV3Interface feed = asset.usdPriceFeed;

        if (address(feed) == address(0)) {
            revert IPool.TvlPriceFeedNotSet(asset.id);
        }

        uint8 feedDecimals = feed.decimals();
        (, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();

        if (price <= 0) {
            revert IPool.TvlPriceInvalid(asset.id, price);
        }
        if (
            updatedAt > block.timestamp ||
            block.timestamp - updatedAt > tvlPriceStalenessTreshold
        ) {
            revert IPool.TvlPriceStale(asset.id, updatedAt);
        }

        uint256 baseExp = uint256(asset.precision) + uint256(feedDecimals);
        usdValue = baseExp <= TVL_USD_DECIMALS
            ? amount * uint256(price) * 10 ** (TVL_USD_DECIMALS - baseExp)
            : (amount * uint256(price)) / 10 ** (baseExp - TVL_USD_DECIMALS);
    }

    /// @notice Returns the total USD value (6-decimal) of the public assets in a deposit transaction.
    /// @dev Reverts with DepositRestrictedAsAssetFeedNotSet if any pubAsset has no registered price feed.
    /// @param stx The shielded transaction to evaluate.
    /// @return depositUsd Sum of USD values for all pubAssets in a deposit transaction.
    function _getDepositUsd(
        ShieldedTransaction calldata stx
    ) internal view returns (uint256 depositUsd) {
        uint256 nPubs = stx.pubAssets.length;
        for (uint256 i; i < nPubs; ) {
            uint24 assetId = uint24(bytes3(bytes31(stx.pubAssets[i])));
            uint224 amount = uint224(stx.pubAssets[i]);
            Asset memory asset = _assets[assetId];
            if (!asset.isActive || address(asset.usdPriceFeed) == address(0)) {
                revert IPool.DepositRestrictedAsAssetFeedNotSet(assetId);
            }
            depositUsd += _getUsdValue(asset, uint256(amount));

            unchecked {
                ++i;
            }
        }
    }
}
