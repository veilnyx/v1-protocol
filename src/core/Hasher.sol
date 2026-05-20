// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IHasher, IPoseidon} from "../interfaces/IHasher.sol";

contract Hasher is IHasher {
    IPoseidon internal immutable _poseidonT3;
    IPoseidon internal immutable _poseidonT4;
    IPoseidon internal immutable _poseidonT5;

    constructor(
        IPoseidon poseidonT3,
        IPoseidon poseidonT4,
        IPoseidon poseidonT5
    ) {
        if (
            address(poseidonT3) == address(0) ||
            address(poseidonT4) == address(0) ||
            address(poseidonT5) == address(0)
        ) revert ZeroAddress();
        _poseidonT3 = poseidonT3;
        _poseidonT4 = poseidonT4;
        _poseidonT5 = poseidonT5;
    }

    function hash(
        uint256[2] calldata inputs
    ) external view override returns (uint256) {
        return _poseidonT3.poseidon(inputs);
    }

    function hash(
        uint256[3] calldata inputs
    ) external view override returns (uint256) {
        return _poseidonT4.poseidon(inputs);
    }

    function hash(
        uint256[] calldata inputs
    ) external view override returns (uint256) {
        if (inputs.length == 3) {
            return _poseidonT4.poseidon([inputs[0], inputs[1], inputs[2]]);
        } else if (inputs.length == 4) {
            return
                _poseidonT5.poseidon(
                    [inputs[0], inputs[1], inputs[2], inputs[3]]
                );
        } else {
            revert("Invalid number of inputs");
        }
    }
}
