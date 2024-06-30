// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IHasher, IPoseidon} from "../interfaces/IHasher.sol";

contract Hasher is IHasher {
    address internal immutable _poseidonT3;
    address internal immutable _poseidonT4;

    constructor(address poseidonT3, address poseidonT4) {
        _poseidonT3 = poseidonT3;
        _poseidonT4 = poseidonT4;
    }

    function hash(
        uint256[2] calldata inputs
    ) external view override returns (uint256) {
        return IPoseidon(_poseidonT3).poseidon(inputs);
    }

    function hash(
        uint256[3] calldata inputs
    ) external view override returns (uint256) {
        return IPoseidon(_poseidonT4).poseidon(inputs);
    }
}
