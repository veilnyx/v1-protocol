// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

// (FIELD_SIZE - 1) / 2 gives exact integer division since FIELD_SIZE is odd
uint256 constant FIELD_SIZE_DIV_2 = (FIELD_SIZE - 1) / 2;

/// @dev BabyJubJub twisted Edwards parameters: a*x^2 + y^2 = 1 + d*x^2*y^2 over FIELD_SIZE.
uint256 constant BABYJUBJUB_A = 168700;
uint256 constant BABYJUBJUB_D = 168696;

type FieldElement is uint256;

uint256 constant ZERO_LEAF = uint256(keccak256("zero")) % FIELD_SIZE;

string constant EIP712_DOMAIN_NAME = "Veilnyx";
string constant EIP712_DOMAIN_VERSION = "1";
bytes32 constant EIP712_TYPEHASH_REGISTER_ADDRESS = keccak256(
    "RegisterAddress(string message,bytes shieldedAddress)"
);
string constant MESSAGE_REGISTER_ADDRESS = "Register Shielded Address";
uint256 constant MAX_WITHDRAW_FEE_BPS = 0.25e4; // 25% in basis points

uint8 constant COMMITMENT_MERKLE_TREE_ROOT_HISTORY_SIZE = 100;
uint8 constant USER_REGISTER_MERKLE_TREE_ROOT_HISTORY_SIZE = 50;

uint8 constant MERKLE_TREE_DEPTH = 20;
uint8 constant COMMITMENT_TREE_DEPTH = 25;
/// @dev Must equal the treeUpdate circuit's `nLeaves` parameter, i.e. the 10 in
///      `TreeUpdate(25, 10)`. It fixes the circuit's public-input count, so the
///      verifier calldata layout depends on it.
uint8 constant TREE_UPDATE_QUEUE_SIZE = 10;
/// @dev TVL values use 6-decimal precision (USDC/USDT DeFi standard).
uint8 constant TVL_USD_DECIMALS = 6;
/// @dev Minimum allowed price staleness threshold (seconds). Prevents operator from
///      accidentally setting it too low (minimum buffer is 1 hour), which would brick all deposit checks.
uint256 constant MIN_PRICE_STALENESS_THRESHOLD = 1 hours;
