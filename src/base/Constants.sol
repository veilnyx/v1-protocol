// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

uint256 constant FIELD_SIZE_DIV_2 = FIELD_SIZE / 2;

uint256 constant ZERO_LEAF = uint256(keccak256("zero")) % FIELD_SIZE;

string constant EIP712_DOMAIN_NAME = "Veilnyx";
string constant EIP712_DOMAIN_VERSION = "2.0";
bytes32 constant EIP712_TYPEHASH_REGISTER_ADDRESS = keccak256(
    "RegisterAddress(string message,bytes shieldedAddress)"
);
string constant MESSAGE_REGISTER_ADDRESS = "Register Shielded Address";
