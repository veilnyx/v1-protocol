// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHasher {
    function poseidon(
        bytes32[2] calldata inputs
    ) external pure returns (bytes32);
}
// interface IHasher {
//     function _hash(uint256 x, uint256 y) external pure returns (uint256 hash);
// }
