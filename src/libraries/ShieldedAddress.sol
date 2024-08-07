// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {FIELD_SIZE_DIV_2} from "../base/Constants.sol";
import {MerkleTree, MerkleTreeLogic} from "./MerkleTree.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";

struct ShieldedAddressRegistrationData {
    bytes proof;
    bytes shieldedAddress; // In uncompressed form
    bytes signature;
}

library ShieldedAddressLogic {
    using MerkleTreeLogic for MerkleTree;

    function register(
        ShieldedAddressRegistrationData calldata self,
        MerkleTree storage addressTree,
        mapping(address => uint256) storage publicAddresses,
        mapping(uint256 => bool) storage rootAddresses,
        address verifier,
        bytes32 hashTypedData
    ) external {
        uint256 rootAddress = uint256(bytes32(self.shieldedAddress[0:32]));

        if (rootAddresses[rootAddress]) {
            revert IPool.RootAddressAlreadyRegistered(rootAddress);
        }

        if (!verifyProof(self, verifier)) {
            revert IPool.InvalidAddressProof();
        }

        address publicAddress = ECDSA.recover(hashTypedData, self.signature);

        if (publicAddresses[publicAddress] != 0) {
            revert IPool.PublicAddressAlreadyRegistered(publicAddress);
        }

        uint32 nextIndex = addressTree.insert(rootAddress);
        rootAddresses[rootAddress] = true;
        publicAddresses[publicAddress] = rootAddress;

        emit IPool.RegisterAddress(
            publicAddress,
            rootAddress,
            nextIndex - 1,
            self.shieldedAddress
        );
    }

    function verifyProof(
        ShieldedAddressRegistrationData calldata self,
        address verifier
    ) internal view returns (bool) {
        bytes memory vInp = abi.encodePacked(self.proof, self.shieldedAddress);
        return IVerifier(verifier).verifyAddressProof(vInp);
    }

    function compress(
        bytes calldata shieldedAddress
    ) public pure returns (bytes memory) {
        bytes32 viewPubKeyX = bytes32(shieldedAddress[32:64]);
        bytes32 viewPubKeyY = bytes32(shieldedAddress[64:96]);
        bytes32 signPubKeyX = bytes32(shieldedAddress[96:128]);
        bytes32 signPubKeyY = bytes32(shieldedAddress[128:160]);

        bytes32 mask = hex"8000000000000000000000000000000000000000000000000000000000000000";

        bytes32 v;
        if (uint256(viewPubKeyX) < FIELD_SIZE_DIV_2) {
            v = mask | bytes32(viewPubKeyY);
        }

        bytes32 s;
        if (uint256(signPubKeyX) < FIELD_SIZE_DIV_2) {
            s = mask | bytes32(signPubKeyY);
        }

        return abi.encodePacked(bytes32(shieldedAddress[0:32]), v, s);
    }
}
