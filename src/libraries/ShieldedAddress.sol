// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {FIELD_SIZE_DIV_2} from "../base/Constants.sol";
import {MerkleTree, MerkleTreeLogic} from "./MerkleTree.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {EIP712_TYPEHASH_REGISTER_ADDRESS, MESSAGE_REGISTER_ADDRESS} from "../base/Constants.sol";
import {console2} from "forge-std/console2.sol";

struct ShieldedAddressRegistrationData {
    bytes proof;
    bytes shieldedAddress; // In uncompressed form
    bytes signature;
}

library ShieldedAddressLogic {
    using MerkleTreeLogic for MerkleTree;

    bytes32 constant MASK_PACK =
        hex"8000000000000000000000000000000000000000000000000000000000000000";

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

        // if (!verifyProof(self, verifier)) {
        //     revert IPool.InvalidAddressProof();
        // }

        console2.log("Recovery process started");
        console2.log("Hash Typed Data on protocol:");
        console2.logBytes32(hashTypedData);
        // console2.log("Signature:", self.signature);

        address publicAddress = ECDSA.recover(hashTypedData, self.signature);
        console2.log("Public Address:", publicAddress);

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
            pack(self.shieldedAddress)
        );
    }

    function verifyProof(
        ShieldedAddressRegistrationData calldata self,
        address verifier
    ) internal view returns (bool) {
        bytes memory vInp = abi.encodePacked(self.proof, self.shieldedAddress);
        return IVerifier(verifier).verifyAddressProof(vInp);
    }

    function pack(
        bytes calldata shieldedAddress
    ) public pure returns (bytes memory) {
        bytes32 vx = bytes32(shieldedAddress[32:64]);
        bytes32 vy = bytes32(shieldedAddress[64:96]);
        bytes32 sx = bytes32(shieldedAddress[96:128]);
        bytes32 sy = bytes32(shieldedAddress[128:160]);

        return
            abi.encodePacked(
                shieldedAddress[0:32],
                _packPoint(vx, vy),
                _packPoint(sx, sy)
            );
    }

    function _packPoint(bytes32 x, bytes32 y) internal pure returns (bytes32) {
        if (uint256(x) > FIELD_SIZE_DIV_2) {
            return MASK_PACK | y;
        }
        return y;
    }

    function hashRegsiterAddressStruct(
        bytes calldata shieldedAddress
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_TYPEHASH_REGISTER_ADDRESS,
                    keccak256(bytes(MESSAGE_REGISTER_ADDRESS)),
                    keccak256(shieldedAddress)
                )
            );
    }
}
