// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

uint256 constant ZERO_LEAF = uint256(keccak256("zkFi")) % FIELD_SIZE;

string constant DOMAIN_NAME = "Labyrinth";
string constant DOMAIN_VERSION = "1";
bytes32 constant LABYRINTH_TYPEHASH = keccak256("Labyrinth(string message,bytes shieldedAddress)");
string constant REGISTRATION_SIGNING_MSG = "Register Shielded Address";

