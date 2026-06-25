// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MerkleTree} from "../libraries/MerkleTreeLogic.sol";
import {QueuedMerkleTree} from "../libraries/QueuedMerkleTreeLogic.sol";
import {Asset, AssetType} from "../libraries/AssetLogic.sol";
import {RevokerData} from "../libraries/ShieldedTransactionLogic.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IAdaptorHandler} from "../interfaces/IAdaptorHandler.sol";
import {IHasher} from "../interfaces/IHasher.sol";
import {IScreener} from "../interfaces/IScreener.sol";
import {IWToken} from "../interfaces/IWToken.sol";

abstract contract PoolStorage {
    IVerifier public verifier;
    IAdaptorHandler public adaptorHandler;
    IHasher public hasher;
    IScreener public screener;

    MerkleTree internal _addressTree;
    QueuedMerkleTree internal _commitmentTree;

    mapping(uint256 => bool) internal _rootAddresses;
    mapping(address => uint256) internal _publicAddresses;

    mapping(AssetType => uint16) internal _assetCounts;
    /// Asset ids are are 3 bytes long - 1 byte for asset type and 2 bytes for asset uid
    mapping(address assetAddress => uint24 assetId) _assetIds;
    mapping(uint24 assetId => Asset asset) _assets;

    mapping(uint256 nullifier => uint32 markNullifierIndex)
        internal _markedNullifiers;

    mapping(IAdaptorHandler => bool) internal _adaptors;

    uint16 internal _revokerCount;
    mapping(uint256 => bool) internal _revokerPublicKeys;
    mapping(uint256 => RevokerData) internal _revokers;

    uint256 public withdrawFeeBps; // 1 bip = 1% / 100
    mapping(uint24 => uint256) internal _withdrawFees;
    mapping(address paymaster => mapping(uint24 assetId => uint256 feeAmount))
        internal _paymasterFees;

    uint64 public version;

    /// @dev TVL guard: maximum allowed TVL in USD, 6-decimal precision (USDC/USDT standard). 0 = disabled.
    uint256 public tvlLimitUsd;

    /// @dev Deposit size limits in USD, 6-decimal precision. 0 = limit disabled.
    uint256 public minDepositUsd;
    uint256 public maxDepositUsd;

    /// @dev Maximum age of a Chainlink price answer before it is considered stale.
    uint256 public priceFeedStalenessThreshold;

    /// @dev Wrapped native token (e.g. WETH) used to convert any incoming msg.value
    ///      into the corresponding ERC20 deposit during a DEPOSIT transaction.
    ///      Must be set by the owner via `setWToken` before native ETH deposits
    ///      are accepted; while unset (address(0)) any `transact` call carrying
    ///      msg.value > 0 reverts. ERC20-only deposits are unaffected.
    IWToken public wToken;

    /// @dev Address authorised to call `pause()`. Set by the owner via `setPauser`.
    ///      Defaults to address(0).
    address public pauser;
}
