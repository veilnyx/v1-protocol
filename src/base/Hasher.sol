// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoseidonT3} from "poseidon-solidity/PoseidonT3.sol";
import {PoseidonT4} from "poseidon-solidity/PoseidonT4.sol";
import {IHasher} from "../interfaces/IHasher.sol";

abstract contract Hasher {
    function _hash(
        uint256 x,
        uint256 y
    ) internal pure virtual returns (uint256) {
        return PoseidonT3.hash([x, y]);
    }

    function _hash(
        uint256 x,
        uint256 y,
        uint256 z
    ) internal pure virtual returns (uint256) {
        return PoseidonT4.hash([x, y, z]);
    }
}
