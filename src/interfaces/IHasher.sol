// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPoseidon {
    function poseidon(
        uint256[2] calldata inputs
    ) external view returns (uint256);

    function poseidon(
        uint256[3] calldata inputs
    ) external view returns (uint256);
}

interface IHasher {
    function hash(uint256[2] calldata inputs) external view returns (uint256);

    function hash(uint256[3] calldata inputs) external view returns (uint256);
}
