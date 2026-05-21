// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

interface IHasher {
    error ZeroAddress();

    function hash(uint256[2] calldata inputs) external view returns (uint256);

    function hash(uint256[3] calldata inputs) external view returns (uint256);

    function hash(uint256[] calldata inputs) external view returns (uint256);
}
