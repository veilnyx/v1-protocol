// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.24;

interface IMerkleTree {
    error OutOfRangeMerkleTreeDepth(uint256 depth);
    error InputOutOfFieldSize(uint256 input);
    error MerkleTreeFull();

    function hashLeaves(
        uint256 left,
        uint256 right
    ) external view returns (uint256);

    function isKnownRoot(uint256 root) external view returns (bool);

    function getLastRoot() external view returns (uint256);
}
