// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IPool, InitAddressParams, PoolConfigParams} from "../interfaces/IPool.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IScreener} from "../interfaces/IScreener.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {IWToken} from "../interfaces/IWToken.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, MAX_WITHDRAW_FEE_BPS, MERKLE_TREE_DEPTH, COMMITMENT_TREE_DEPTH, TVL_USD_DECIMALS, MIN_PRICE_STALENESS_THRESHOLD} from "../base/Constants.sol";
import {PoolStorage} from "../base/PoolStorage.sol";
import {Asset, AssetType, AssetLogic, AssetInitParams} from "../libraries/AssetLogic.sol";
import {MerkleTree, MerkleTreeLogic} from "../libraries/MerkleTreeLogic.sol";
import {QueuedMerkleTree, QueuedMerkleTreeLogic, TreeUpdateData} from "../libraries/QueuedMerkleTreeLogic.sol";
import {ShieldedAddressRegistrationData, ShieldedAddressLogic} from "../libraries/ShieldedAddressLogic.sol";
import {ShieldedTransaction, ShieldedTransactionLogic, ShieldedTransactionType, RevokerData} from "../libraries/ShieldedTransactionLogic.sol";

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
    /// @param commitmentTreeQueueSize The size of the queue for the commitment tree. This determines how many leaves can be queued at MAX before a tree update is required. Defined by the circuit `treeUpdate::nLeaves`
    function initialize(
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
        if (
            configParams.priceFeedStalenessThreshold <
            MIN_PRICE_STALENESS_THRESHOLD
        ) {
            revert IPool.PriceFeedStalenessThresholdTooLow(
                configParams.priceFeedStalenessThreshold,
                MIN_PRICE_STALENESS_THRESHOLD
            );
        }
        _validateDepositLimits(
            configParams.minDepositUsd,
            configParams.maxDepositUsd
        );

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
        priceFeedStalenessThreshold = configParams.priceFeedStalenessThreshold;
        nativeWToken = configParams.nativeWToken;

        _addressTree.init(hasher);
        _commitmentTree.init(commitmentTreeQueueSize, hasher, verifier);
    }

    /////////////////////////////////////////
    //            MODIFIERS               //
    ////////////////////////////////////////

    /// @dev Reverts unless the caller is the designated pauser or the owner.
    modifier onlyPauserOrOwner() {
        if (msg.sender != pauser && msg.sender != owner())
            revert IPool.NotPauser();
        _;
    }

    /////////////////////////////////////////
    //         ADMIN WRITE METHODS         //
    ////////////////////////////////////////
    /// @custom:invariant ACCESS-1 Owner can upgrade, pause, add assets/adaptors, register revokers
    function pause() external onlyPauserOrOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @custom:invariant ACCESS-1 Owner can delegate pausing to a separate address
    function setPauser(address newPauser) external onlyOwner {
        emit IPool.PauserUpdated(pauser, newPauser);
        pauser = newPauser;
    }

    function addAssets(
        AssetType assetType,
        AssetInitParams[] calldata initParams
    ) external onlyOwner {
        _assetCounts[assetType] = AssetLogic.addAssets({
            assetIds: _assetIds,
            assets: _assets,
            assetCount: _assetCounts[assetType],
            assetType: assetType,
            initParams: initParams
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

    /// @notice Sets the sanctions screener contract.
    /// @dev Setting `screener_` to the zero address disables screening entirely:
    ///      registrations and deposits then proceed without a sanctions check.
    ///      This is an intentional kill-switch — if the external screener becomes
    ///      unavailable or starts reverting, the owner can disable screening to
    ///      keep the protocol live rather than have core flows revert. Re-enable
    ///      by setting a working screener again. Emits {ScreenerUpdated}.
    ///      Any non-zero `screener_` must be a contract: setting an EOA would
    ///      make `isSanctioned` revert and brick registrations and deposits.
    function setScreener(IScreener screener_) external onlyOwner {
        if (
            address(screener_) != address(0) &&
            address(screener_).code.length == 0
        ) {
            revert IPool.InvalidScreenerAddress(address(screener_));
        }

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
    ///         Set to type(uint256).max to disable the TVL cap entirely.
    /// @custom:invariant TVL-1: deposits that push TVL above tvlLimitUsd are reverted
    function setTvlLimitUsd(uint256 limitUsd) external onlyOwner {
        if (tvlLimitUsd != limitUsd) {
            tvlLimitUsd = limitUsd;
            emit IPool.TvlLimitUpdated(limitUsd);
        }
    }

    /// @notice Sets both deposit limits atomically.
    /// @dev Reverts with BadArguments if min > 0, max != type(uint256).max, and min > max.
    function setDepositLimits(
        uint256 minUsd,
        uint256 maxUsd
    ) external onlyOwner {
        _validateDepositLimits(minUsd, maxUsd);
        if (minDepositUsd != minUsd) {
            minDepositUsd = minUsd;
            emit IPool.MinDepositUpdated(minUsd);
        }
        if (maxDepositUsd != maxUsd) {
            maxDepositUsd = maxUsd;
            emit IPool.MaxDepositUpdated(maxUsd);
        }
    }

    /// @notice Sets the maximum age of a Chainlink price answer before it is considered stale.
    /// @param threshold Age in seconds. Must be >= MIN_PRICE_STALENESS_THRESHOLD (1 hour).
    function setPriceFeedStalenessThreshold(
        uint256 threshold
    ) external onlyOwner {
        if (threshold < MIN_PRICE_STALENESS_THRESHOLD) {
            revert IPool.PriceFeedStalenessThresholdTooLow(
                threshold,
                MIN_PRICE_STALENESS_THRESHOLD
            );
        }
        if (priceFeedStalenessThreshold != threshold) {
            priceFeedStalenessThreshold = threshold;
            emit IPool.PriceFeedStalenessThresholdUpdated(threshold);
        }
    }

    /// @notice Sets the wrapped native token (e.g. WETH) used to convert any
    ///         incoming `msg.value` into the corresponding ERC20 deposit
    ///         during a DEPOSIT transaction.
    /// @dev    Setting `nativeWToken_` to address(0) disables native ETH deposits via
    ///         this Pool: any `transact` call carrying `msg.value` will revert.
    ///         The `nativeWToken_` address must also be registered as an active
    ///         ERC20 asset (via `addAssets`) for native ETH deposits to be
    ///         accepted at runtime.
    /// @param nativeWToken_ The wrapped native token contract.
    function setNativeWToken(IWToken nativeWToken_) external onlyOwner {
        if (nativeWToken != nativeWToken_) {
            nativeWToken = nativeWToken_;
            emit IPool.NativeWTokenUpdated(nativeWToken_);
        }
    }

    /// @notice Renouncing ownership is disabled. owner() is the only account that can configure
    ///         assets, revokers, fees, limits and upgrades, so it must always exist. Use
    ///         transferOwnership to change it.
    /// @dev    Reverts with `IPool.RenounceDisabled` for the owner
    function renounceOwnership() public view override onlyOwner {
        revert IPool.RenounceDisabled();
    }

    /////////////////////////////////////////
    //        PUBLIC WRITE METHODS         //
    ////////////////////////////////////////

    function registerAddress(
        ShieldedAddressRegistrationData calldata addressRegData
    ) external whenNotPaused {
        _screenForSanctionedAddr(msg.sender);

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
    ) public payable nonReentrant whenNotPaused {
        _validateNoDuplicatePubAssets(stx);
        _runDepositGuardRails(stx);
        stx.validate({
            addressTree: _addressTree,
            commitmentTree: _commitmentTree,
            verifier: verifier,
            markedNullifiers: _markedNullifiers,
            supportedAdaptors: _adaptors,
            revokerDataMap: _revokers
        });

        // Resolve the nativeWToken and its asset ID once; used for both DEPOSIT
        // wrapping and WITHDRAW unwrapping so storage is read only once.
        IWToken _wToken = nativeWToken;
        uint24 _wTokenAssetId = _resolveWTokenAssetId(_wToken);

        // If the caller attached native ETH, wrap it into wToken up-front so
        // the ensuing deposit logic can treat the wToken portion as already
        // credited to the Pool. msg.value == 0 preserves the ERC20
        // transferFrom flow for every pubAsset (including wToken).
        if (msg.value > 0) {
            _wrapNativeEthForDeposit(stx, _wToken, _wTokenAssetId);
        }

        stx.execute({
            commitmentTree: _commitmentTree,
            assets: _assets,
            paymasterFees: _paymasterFees,
            withdrawFees: _withdrawFees,
            hasher: hasher,
            adaptorHandler: adaptorHandler,
            withdrawFeeBps: withdrawFeeBps,
            wToken_: _wToken,
            wTokenAssetId: _wTokenAssetId
        });
    }

    /// @dev Accepts native ETH sent back by the nativeWToken contract during WITHDRAW unwrapping.
    ///      Reverts for any other sender to prevent accidental ETH from becoming permanently stuck.
    receive() external payable {
        if (address(nativeWToken) == address(0))
            revert IPool.NativeWTokenNotConfigured();
        if (msg.sender != address(nativeWToken))
            revert IPool.UnexpectedNativeEthSender(msg.sender);
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

    /// @notice Validates that the deposit amount in `stx` falls within the configured USD limits.
    /// @dev Call this before submitting a DEPOSIT transaction to surface limit violations early,
    ///      without spending gas on a full transaction. Non-DEPOSIT transactions always pass.
    ///      Limits are expressed in 6-decimal USD (e.g. 5_000_000 = $5.00).
    /// @param stx The shielded transaction to validate.
    /// @custom:error DepositRestrictedAsAssetFeedNotSet Thrown when any deposit asset has no registered USD price feed.
    /// @custom:error DepositBelowMinimum Thrown when `minDepositUsd > 0` and the deposit
    ///               value is strictly less than `minDepositUsd`.
    /// @custom:error DepositAboveMaximum Thrown when `maxDepositUsd > 0` and the deposit
    ///               value is strictly greater than `maxDepositUsd`.
    function checkDepositWithinLimits(
        ShieldedTransaction calldata stx
    ) public view returns (bool) {
        if (stx.txType != ShieldedTransactionType.DEPOSIT) return true;
        uint256 _min = minDepositUsd;
        uint256 _max = maxDepositUsd;
        if (_min == 0 && _max == type(uint256).max) return true;

        uint256 depositUsd = _getDepositUsd(stx);
        if (depositUsd < _min)
            revert IPool.DepositBelowMinimum(depositUsd, _min);
        if (depositUsd > _max)
            revert IPool.DepositAboveMaximum(depositUsd, _max);
        return true;
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
        if (
            tvlLimitUsd == type(uint256).max ||
            stx.txType != ShieldedTransactionType.DEPOSIT
        ) {
            return false;
        }
        crossed = getTvlUsd() + _getDepositUsd(stx) > tvlLimitUsd;
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
            uint256[COMMITMENT_TREE_DEPTH] memory lastSubtrees,
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
            uint256[MERKLE_TREE_DEPTH] memory lastSubtrees,
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

    /// @dev Reverts if both limits are meaningful and min > max.
    ///      0 = no minimum; type(uint256).max = no maximum.
    function _validateDepositLimits(uint256 min, uint256 max) private pure {
        if (min > 0 && max != type(uint256).max && min > max)
            revert IPool.BadArguments();
    }

    function _setAssetPriceFeed(
        uint24 assetId,
        AggregatorV3Interface feed
    ) private {
        AssetLogic.setAssetPriceFeed(_assets, assetId, feed);
        emit IPool.AssetUsdPriceFeedSet(assetId, feed);
    }

    /// @dev Screens `account` against the configured sanctions screener.
    /// @dev Reverts with {IScreener.SanctionedAddress} when `account` is flagged.
    function _screenForSanctionedAddr(address account) internal view {
        IScreener _screener = screener;
        if (
            address(_screener) != address(0) && _screener.isSanctioned(account)
        ) {
            revert IScreener.SanctionedAddress(account);
        }
    }

    /// @dev Runs all deposit guard-rail checks — deposit min/max limits and TVL cap
    function _runDepositGuardRails(
        ShieldedTransaction calldata stx
    ) private view {
        if (stx.txType != ShieldedTransactionType.DEPOSIT) return;
        _screenForSanctionedAddr(msg.sender);

        uint256 _min = minDepositUsd;
        uint256 _max = maxDepositUsd;
        uint256 _tvl = tvlLimitUsd;
        // All limits disabled — skip oracle call entirely
        if (_min == 0 && _max == type(uint256).max && _tvl == type(uint256).max)
            return;

        uint256 depositUsd = _getDepositUsd(stx);

        if (depositUsd < _min) {
            revert IPool.DepositBelowMinimum(depositUsd, _min);
        }
        if (depositUsd > _max) {
            revert IPool.DepositAboveMaximum(depositUsd, _max);
        }

        if (_tvl != type(uint256).max) {
            uint256 projectedTvl = getTvlUsd() + depositUsd;
            if (projectedTvl > _tvl) {
                revert IPool.TvlLimitExceeded(projectedTvl, _tvl);
            }
        }
    }

    /// @notice Returns the USD value of `amount` units of `asset` using its registered Chainlink feed.
    /// @dev Reverts with PriceFeedValueStale / PriceFeedValueInvalid on bad feed data.
    /// @param asset  The Asset struct (must have usdPriceFeed set).
    /// @param amount Raw token amount (in the asset's native precision).
    /// @return usdValue Amount expressed in 6-decimal USD.
    function _getUsdValue(
        Asset memory asset,
        uint256 amount
    ) internal view returns (uint256 usdValue) {
        AggregatorV3Interface feed = asset.usdPriceFeed;

        (, int256 price, , uint256 updatedAt, ) = feed.latestRoundData();

        if (price <= 0) {
            revert IPool.PriceFeedValueInvalid(asset.id, price);
        }
        if (
            updatedAt > block.timestamp ||
            block.timestamp - updatedAt > priceFeedStalenessThreshold
        ) {
            revert IPool.PriceFeedValueStale(asset.id, updatedAt);
        }

        uint256 baseExp = uint256(asset.precision) +
            uint256(asset.feedDecimals);
        usdValue = baseExp <= TVL_USD_DECIMALS
            ? amount * uint256(price) * 10 ** (TVL_USD_DECIMALS - baseExp)
            : Math.mulDiv(
                amount,
                uint256(price),
                10 ** (baseExp - TVL_USD_DECIMALS)
            );
    }

    /// @notice Returns the total USD value (6-decimal) of the public assets in a deposit transaction.
    /// @dev Reverts with DepositRestrictedAsAssetFeedNotSet if the deposit asset has no registered price feed.
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
            if (!asset.isActive) {
                revert IPool.InactiveAsset(assetId);
            }
            if (address(asset.usdPriceFeed) == address(0)) {
                revert IPool.DepositRestrictedAsAssetFeedNotSet(assetId);
            }
            depositUsd += _getUsdValue(asset, uint256(amount));

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns the current total value locked in USD (6-decimal precision, USDC/USDT standard)
    ///         across all active ERC20 assets, using registered Chainlink USD price feeds.
    /// @dev Assets with no registered feed or that are inactive contribute 0 to the TVL.
    ///      Reverts with PriceFeedValueStale if a feed's answer is older than TVL_PRICE_STALENESS_THRESHOLD.
    ///      Reverts with PriceFeedValueInvalid if a feed returns a non-positive price.
    /// @return tvl Cumulative TVL in 6-decimal USD (e.g. 1_000_000 = $1).
    function getTvlUsd() public view returns (uint256 tvl) {
        uint16 erc20Count = _assetCounts[AssetType.ERC20];
        for (uint16 i = 1; i <= erc20Count; ) {
            uint24 assetId = (uint24(uint8(AssetType.ERC20)) << 16) | uint24(i);
            Asset memory asset = _assets[assetId];

            if (asset.isActive && address(asset.usdPriceFeed) != address(0)) {
                uint256 rawBalance = IERC20(asset.assetAddress).balanceOf(
                    address(this)
                );
                tvl += _getUsdValue(asset, rawBalance);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Validates that no assetId appears more than once in stx.pubAssets. This is essential to prevent reduction of `msg.value` from being deducted from multiple pubAssets with the same assetId. Reverts with DuplicatePubAssetId if a duplicate is found. Ref _wrapNativeEthForDeposit().
    function _validateNoDuplicatePubAssets(
        ShieldedTransaction calldata stx
    ) internal pure {
        uint256 n = stx.pubAssets.length;
        for (uint256 i; i < n; ) {
            uint24 idI = uint24(bytes3(bytes31(stx.pubAssets[i])));
            for (uint256 j = i + 1; j < n; ) {
                uint24 idJ = uint24(bytes3(bytes31(stx.pubAssets[j])));
                if (idI == idJ) revert IPool.DuplicatePubAssetId(idI);
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns the asset id of `_wToken_` in this pool, or 0 if it is
    ///         not configured or not registered as an asset. Does not revert.
    ///         Used by `transact` to drive both the DEPOSIT wrap path and the
    ///         WITHDRAW unwrap path without reading wToken storage twice.
    function _resolveWTokenAssetId(
        IWToken _wToken_
    ) internal view returns (uint24) {
        if (address(_wToken_) == address(0)) return 0;
        return _assetIds[address(_wToken_)];
    }

    /// @notice Wraps the attached `msg.value` into the configured wToken so it
    ///         can be used as the wToken portion of a DEPOSIT.
    /// @dev    Called from `transact` only when `msg.value > 0`. Validates that
    ///         the call shape is consistent with wrapping native ETH:
    ///         - `txType` must be DEPOSIT (otherwise the ETH would be locked).
    ///         - `wToken` must be configured and registered as an active
    ///           ERC20 asset (otherwise wrapping has no destination).
    ///         - exactly one pubAsset must reference the wToken's asset id, otherwise can lead to deduction of `msg.value` from multiple pubAssets with the same assetId.
    ///         - `msg.value` must be `<=` that pubAsset's full value
    ///           so no surplus ETH is locked in the Pool. Strict-less means
    ///           the caller has chosen to top up the deposit by approving the
    ///           remainder in wToken (ERC20) form; we pull that delta with
    ///           `transferFrom(msg.sender, address(this), delta)` so the Pool
    ///           ends up holding the full `wTokenValue` of wToken before the
    ///           library proceeds. The library skips its own per-asset
    ///           `transferFrom` for the wToken id via `prefundedAssetId`.
    /// @param  stx The shielded transaction being executed.
    /// @param  _wToken_ The resolved wToken contract (from `_resolveWTokenAssetId`).
    /// @param  wTokenAssetId The resolved wToken asset id (from `_resolveWTokenAssetId`).
    function _wrapNativeEthForDeposit(
        ShieldedTransaction calldata stx,
        IWToken _wToken_,
        uint24 wTokenAssetId
    ) internal {
        if (stx.txType != ShieldedTransactionType.DEPOSIT) {
            revert IPool.NativeEthProvidedForNonDepositTx();
        }

        if (address(_wToken_) == address(0)) {
            revert IPool.NativeWTokenNotConfigured();
        }

        if (wTokenAssetId == 0 || !_assets[wTokenAssetId].isActive) {
            revert IPool.NativeWTokenNotConfigured();
        }

        uint256 nPubs = stx.pubAssets.length;
        bool found;
        uint256 wTokenValue;
        for (uint256 i; i < nPubs; ) {
            uint24 id = uint24(bytes3(bytes31(stx.pubAssets[i])));
            if (id == wTokenAssetId) {
                if (found) {
                    // A well-formed stx must not list the same assetId twice
                    // in pubAssets. Reject early so that msg.value does not get deducted from multiple pubAssets with the same assetId.
                    revert IPool.DuplicatePubAssetId(id);
                }
                wTokenValue = uint224(stx.pubAssets[i]);
                found = true;
            }
            unchecked {
                ++i;
            }
        }

        if (!found) {
            revert IPool.WTokenNotInPubAssets();
        }
        if (msg.value > wTokenValue) {
            revert IPool.NativeEthExceedsDeposit(msg.value, wTokenValue);
        }

        // Wrap the attached native ETH into wToken; the resulting wToken
        // balance is held directly by this Pool.
        _wToken_.deposit{value: msg.value}();

        // If the caller chose to fund only part of the deposit with native
        // ETH, pull the remainder in wToken (ERC20) form. This requires the
        // caller to have approved at least (wTokenValue - msg.value) of
        // wToken to this Pool. Combined with the wrap above, the Pool now
        // holds exactly `wTokenValue` of wToken for this deposit, allowing
        // the library to skip its own transferFrom for the wToken id.
        uint256 remainder = wTokenValue - msg.value;
        if (remainder != 0) {
            AssetLogic.receiveAsset({
                assets: _assets,
                from: msg.sender,
                assetId: wTokenAssetId,
                value: remainder
            });
        }
    }
}
