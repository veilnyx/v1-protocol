// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

enum AssetType {
    NULL,
    ERC20,
    ERC721,
    ERC1155
}

enum MemoType {
    NULL,
    SEMI,
    FULL
}

struct Asset {
    AssetType assetType;
    address assetAddress;
    bool isSupported;
}

struct Proof {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

struct VerifierInfo {
    uint16 id;
    address addr;
    bytes4 selector;
}
