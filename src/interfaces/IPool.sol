// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IPool {
    event NullifierMarked(uint256 indexed nullifier);

    event Announcement(uint256 leafIndex, uint256 commitment, bytes memo);

    error InvalidProof();
    error UnexpectedFee();
    error UnknownMerkleRoot();
    error DoubleSpend(uint256 markedNullifier);
    error InvalidDataHash(uint256 dataHash);
    error UnsupportedProxy();
}
