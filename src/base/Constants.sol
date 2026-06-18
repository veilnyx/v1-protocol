// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

// (FIELD_SIZE - 1) / 2 gives exact integer division since FIELD_SIZE is odd
uint256 constant FIELD_SIZE_DIV_2 = (FIELD_SIZE - 1) / 2;

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
